"""Background scheduler that delivers medicine reminders via Web Push + FCM.

Runs once a minute. For every patient with medicines it computes their LOCAL
clock and pushes three stages of reminder to the patient and to each of their
active caretakers — so the alarm fires even when the app is completely closed:

  pre     T-30 min   "upcoming dose" heads-up
  dose    T          the dose-time alarm (the original behaviour)
  verify  T+10 min   "did you take it?" — ONLY if no taken/skipped intake was
                     logged for that slot today

Design notes:
  - One in-process asyncio task; the per-minute work runs in a worker thread so
    blocking DB/HTTP calls never stall the event loop.
  - The loop is driven by PATIENTS, not by push subscriptions. A dose belongs
    to a patient and resolves in the patient's timezone; recipients are derived
    from it. A caretaker in another zone is therefore notified at the patient's
    dose time, not shifted into their own.
  - Dedupe lives in the reminder_deliveries table, keyed by
    (medicine, recipient, dose slot, channel). Each stage claims its own row by
    using its own channel value, so the three stages never collide — while the
    dose stage keeps the historical "webpush" value so pre-existing rows stay
    valid across this change. That survives restarts — the previous in-memory
    set did not — and it also means a caretaker who links mid-day is never
    backfilled with slots that already passed.
  - Safe with multiple workers: a duplicate insert loses the unique-constraint
    race and is skipped rather than sent twice.
"""

import asyncio
import logging
from dataclasses import dataclass
from datetime import datetime, timezone as dt_timezone

from sqlalchemy.exc import IntegrityError
from sqlmodel import Session, select

from app.core import doses
from app.core.config import engine, settings
from app.core.fcm import fcm_available, send_fcm
from app.core.webpush import push_available, send_push
from app.models.models import (
    CareLink,
    FcmToken,
    Medicine,
    MedicineIntakeLog,
    PushSubscription,
    ReminderDelivery,
    User,
)

logger = logging.getLogger("medicine_reminders")

_TICK_SECONDS = 60

# Fire a dose if its scheduled minute is within the last GRACE_MINUTES, not only
# the exact current minute. This is what makes reminders survive a free-tier
# instance that was asleep (or a delayed tick): when it wakes, it still delivers
# any dose due in the recent window instead of missing it forever. The delivery
# ledger keeps each dose to a single push, so the window never double-sends.
GRACE_MINUTES = 10

# The pre-reminder leads the dose time by this many minutes; the verification
# nag follows it by the same question an hour would be too late for. Both get
# the same GRACE_MINUTES late window as the dose stage, so a sleepy server that
# wakes anywhere inside [T-X, T-X+GRACE] still fires stage X exactly once.
PRE_MINUTES = 30
VERIFY_MINUTES = 10

CHANNEL = "webpush"
CHANNEL_PRE = "webpush-pre"
CHANNEL_VERIFY = "webpush-verify"

_STAGES = ("pre", "dose", "verify")

_CHANNEL_BY_STAGE = {
    "pre": CHANNEL_PRE,
    "dose": CHANNEL,
    "verify": CHANNEL_VERIFY,
}

# Intake outcomes that mean the verification nag has nothing to ask. A snooze
# is deliberately absent: postponed is precisely what verify should chase.
_SETTLED_INTAKE = {"taken", "skipped"}


def reminders_available() -> bool:
    """Any delivery transport configured? The scheduler needs at least one."""
    return push_available() or fcm_available()


@dataclass(frozen=True)
class Recipient:
    user_id: str
    is_self: bool
    # When the care link was created (UTC), for caretakers only. A dose slot
    # that predates it is not theirs to hear about — see _eligible_for.
    linked_at: datetime | None = None


def _delta_minutes(scheduled: str, now: datetime) -> int | None:
    """Minutes since `scheduled` (HH:MM) hit, in the patient's local clock.
    Negative means the slot is still ahead."""
    sched = doses.minutes_of_day(scheduled)
    if sched is None:
        return None
    now_min = now.hour * 60 + now.minute
    return now_min - sched


def _stage_for(delta: int) -> str | None:
    """Which reminder stage (if any) covers a slot `delta` minutes from now.

    Windows are GRACE_MINUTES wide so a tick delayed by a sleeping instance
    still lands inside one. `dose` wins ties against `verify`: a slot that
    crossed both boundaries while the server slept announces the dose first and
    lets a later tick in the verify window ask the follow-up question.
    """
    if -PRE_MINUTES <= delta <= -PRE_MINUTES + GRACE_MINUTES:
        return "pre"
    if 0 <= delta <= GRACE_MINUTES:
        return "dose"
    if VERIFY_MINUTES <= delta <= VERIFY_MINUTES + GRACE_MINUTES:
        return "verify"
    return None


def recipients_for(patient_id: str, links: list[CareLink]) -> list[Recipient]:
    """The patient, plus every active caretaker who hasn't muted them.

    `links` is the patient's pre-loaded active care links. With none it's just
    [patient] — byte-for-byte the behaviour before the feature existed.
    """
    out = [Recipient(user_id=patient_id, is_self=True)]
    for link in links:
        if link.notify:
            out.append(
                Recipient(
                    user_id=link.caretaker_id,
                    is_self=False,
                    linked_at=link.created_at,
                )
            )
    return out


def _eligible_for(
    db: Session, recipient: Recipient, *, medicine_id: str, scheduled_for: datetime
) -> bool:
    """Whether this recipient should hear about this dose slot.

    A caretaker's own ledger row can't answer this — they have none for a slot
    that fired before they existed, so the next tick would happily "catch them
    up" on the morning's dose. Ask instead whether the slot already went out to
    *anyone* before the link was made. If it did, it happened while they were
    not yet a caretaker, and it isn't theirs to hear about.

    Comparing against the slot time itself would be wrong: slots are truncated
    to the minute, so someone linking at 08:00:30 for an 08:00 dose would be
    judged late by thirty seconds.
    """
    if recipient.is_self or recipient.linked_at is None:
        return True

    earlier = db.exec(
        select(ReminderDelivery).where(
            ReminderDelivery.medicine_id == medicine_id,
            ReminderDelivery.scheduled_for == scheduled_for,
            ReminderDelivery.created_at <= recipient.linked_at,
        )
    ).first()
    return earlier is None


def _claim(
    db: Session,
    *,
    medicine_id: str,
    patient_id: str,
    recipient_id: str,
    scheduled_for: datetime,
    stage: str,
) -> ReminderDelivery | None:
    """Reserve this (dose slot, stage, recipient) triple, or None if delivered.

    The unique constraint is the arbiter: whoever inserts first owns the send.
    A loser rolls back and skips, which is what makes repeated ticks — and
    concurrent workers — idempotent. Stages claim separate rows because the
    channel column carries the stage.
    """
    row = ReminderDelivery(
        medicine_id=medicine_id,
        patient_id=patient_id,
        recipient_id=recipient_id,
        scheduled_for=scheduled_for,
        channel=_CHANNEL_BY_STAGE[stage],
        status="skipped",
    )
    try:
        db.add(row)
        db.commit()
        db.refresh(row)
        return row
    except IntegrityError:
        db.rollback()
        return None


def _dose_settled(
    db: Session, *, medicine_id: str, slot: str, day_start_utc: datetime
) -> bool:
    """True when this slot was already accounted for today: logged taken or
    skipped since the patient's local midnight. Snoozed doses still nag.

    Intake logs carry no date column, so "today" means recorded_at after the
    patient-local midnight converted to naive UTC — the same convention every
    timestamp in this schema uses.
    """
    log = db.exec(
        select(MedicineIntakeLog).where(
            MedicineIntakeLog.medicine_id == medicine_id,
            MedicineIntakeLog.scheduled_time == slot,
            MedicineIntakeLog.recorded_at >= day_start_utc,
            MedicineIntakeLog.status.in_(_SETTLED_INTAKE),  # type: ignore[attr-defined]
        )
    ).first()
    return log is not None


def _deliver(
    db: Session,
    subs: list[PushSubscription],
    fcm_tokens: list[FcmToken],
    payload: dict,
    row: ReminderDelivery,
) -> bool:
    """Push to every device the recipient has, recording the outcome.

    [subs] is the recipient's pre-loaded Web Push subscription list.
    [fcm_tokens] is the recipient's pre-loaded FCM device tokens.
    """
    if not subs and not fcm_tokens:
        row.status = "skipped"
        row.error = "no push subscription"
        db.add(row)
        db.commit()
        return False

    sent = False
    errors: list[str] = []

    for sub in subs:
        try:
            result = send_push(sub.endpoint, sub.p256dh, sub.auth, payload)
        except Exception as exc:  # pragma: no cover - defensive
            errors.append(str(exc))
            continue

        if result.ok:
            sent = True
        else:
            errors.append(result.error or "unknown")
            if result.gone:
                try:
                    db.delete(sub)
                except Exception:
                    pass

    for fcm in fcm_tokens:
        try:
            result = send_fcm(fcm.token, payload)
        except Exception as exc:
            errors.append(str(exc))
            continue
        if result.ok:
            sent = True
        else:
            errors.append(result.error or "unknown")
            if result.invalid_token:
                try:
                    db.delete(fcm)
                except Exception:
                    pass

    row.status = "sent" if sent else "failed"
    row.error = None if sent else "; ".join(errors)[:500]
    db.add(row)
    db.commit()
    return sent


def _payload(
    med: Medicine,
    patient_name: str,
    slot: str,
    day: str,
    recipient: Recipient,
    stage: str = "dose",
) -> dict:
    """Reminder copy per stage. A caretaker may be watching several people at
    once, so theirs always leads with the patient's name — otherwise two
    clients' reminders are indistinguishable."""
    who = "" if recipient.is_self else f"{patient_name} — "

    if stage == "pre":
        if recipient.is_self:
            title = "⏰ Dose coming up"
            body = f"{med.name} {med.dosage} at {slot}"
        else:
            title = f"⏰ {patient_name}"
            body = f"{med.name} {med.dosage} due at {slot}"
    elif stage == "verify":
        title = "💊 Did you take it?" if recipient.is_self else f"💊 {patient_name}"
        body = (
            f"{med.name} {med.dosage} ({slot}) — confirm you took it"
            if recipient.is_self
            else f"{who}{med.name} {med.dosage} ({slot}) not confirmed yet"
        )
    else:
        if recipient.is_self:
            title = "💊 Medicine Reminder"
            body = f"Time for {med.name} {med.dosage}"
        else:
            title = f"💊 {patient_name}"
            body = f"{who}{med.name} {med.dosage} due now"

    return {
        "title": title,
        "body": body,
        "stage": stage,
        "medId": med.id,
        "name": med.name,
        "dosage": med.dosage,
        "time": slot,
        "tag": f"{med.id}-{slot}-{day}-{recipient.user_id}-{stage}",
        "forSelf": recipient.is_self,
        "patient_name": patient_name if not recipient.is_self else None,
    }


def _users_by_id(db: Session, user_ids: list[str]) -> dict[str, User]:
    if not user_ids:
        return {}
    return {
        u.id: u
        for u in db.exec(select(User).where(User.id.in_(user_ids))).all()  # type: ignore[attr-defined]
    }


def _newest_subscription_by_user(
    db: Session, user_ids: list[str]
) -> dict[str, PushSubscription]:
    """Each user's most recently registered push device, in one query.

    Ordered newest-first so the first row seen per user is the one to keep —
    same rule as the single-patient path in doses.patient_timezone.
    """
    newest: dict[str, PushSubscription] = {}
    if not user_ids:
        return newest
    for sub in db.exec(
        select(PushSubscription)
        .where(PushSubscription.user_id.in_(user_ids))  # type: ignore[attr-defined]
        .order_by(PushSubscription.created_at.desc())  # type: ignore[union-attr]
    ).all():
        newest.setdefault(sub.user_id, sub)
    return newest


def _subscriptions_for(
    db: Session, user_ids: list[str]
) -> dict[str, list[PushSubscription]]:
    """All subscriptions for [user_ids] in one query, grouped by owner."""
    subs: dict[str, list[PushSubscription]] = {}
    if not user_ids:
        return subs
    for sub in db.exec(
        select(PushSubscription).where(PushSubscription.user_id.in_(user_ids))
    ).all():
        subs.setdefault(sub.user_id, []).append(sub)
    return subs


def _patient_timezone(user: User | None, subs: list[PushSubscription]) -> str:
    """The patient's IANA zone from already-loaded rows, mirroring
    `doses.patient_timezone`: the user's column wins, then the newest push
    device's zone, else UTC. Never queries the database itself."""
    if user is not None and user.timezone:
        return user.timezone
    for sub in sorted(
        subs, key=lambda s: s.created_at or datetime.min, reverse=True
    ):
        if sub.timezone:
            return sub.timezone
    return doses.DEFAULT_TZ


def _run_tick() -> int:
    """One synchronous pass over all patients (runs in a worker thread).

    Returns the number of pushes sent — handy for the external-cron endpoint.

    Every query here is batched across the whole patient set on purpose. The
    per-patient prefix — medicines, the user row, the newest push device — runs
    for EVERY patient on EVERY tick, before the early return that skips those
    with nothing due. Issued one patient at a time that was three round trips
    each (Sentry: PYTHON-FASTAPI-A, 852ms across 12 spans for four patients),
    growing linearly with signups on a job that fires once a minute. Batched,
    the tick costs four queries whether there are four patients or four
    hundred. The intake-log lookups behind the verify stage stay lazy: they
    only run for slots actually sitting in the verify window.
    """
    if not reminders_available():
        return 0

    sent_count = 0
    with Session(engine, expire_on_commit=False) as db:
        meds_by_patient: dict[str, list[Medicine]] = {}
        for med in db.exec(
            select(Medicine).where(
                Medicine.deleted_at.is_(None)  # type: ignore[union-attr]
            )
        ).all():
            meds_by_patient.setdefault(med.user_id, []).append(med)

        patient_ids = list(meds_by_patient)
        if not patient_ids:
            return 0

        users_by_id = _users_by_id(db, patient_ids)

        care_links = (
            list(
                db.exec(
                    select(CareLink).where(
                        CareLink.patient_id.in_(patient_ids),  # type: ignore[attr-defined]
                        CareLink.status == "active",
                    )
                ).all()
            )
            if settings.caretaker_enabled
            else []
        )

        recipient_ids = set(patient_ids) | {
            link.caretaker_id for link in care_links if link.notify
        }

        # Web Push subscriptions
        subs_by_user: dict[str, list[PushSubscription]] = {}
        if recipient_ids:
            for sub in db.exec(
                select(PushSubscription).where(
                    PushSubscription.user_id.in_(recipient_ids)  # type: ignore[attr-defined]
                )
            ).all():
                subs_by_user.setdefault(sub.user_id, []).append(sub)

        newest_sub: dict[str, PushSubscription] = {}
        for user_id, subs_list in subs_by_user.items():
            newest_sub[user_id] = max(
                subs_list, key=lambda s: s.created_at or datetime.min
            )

        # FCM device tokens (mobile apps)
        fcm_by_user: dict[str, list[FcmToken]] = {}
        if recipient_ids:
            for fcm in db.exec(
                select(FcmToken).where(
                    FcmToken.user_id.in_(recipient_ids)  # type: ignore[attr-defined]
                )
            ).all():
                fcm_by_user.setdefault(fcm.user_id, []).append(fcm)

        links_by_patient: dict[str, list[CareLink]] = {}
        for link in care_links:
            links_by_patient.setdefault(link.patient_id, []).append(link)

        for patient_id in patient_ids:
            try:
                sent_count += _tick_patient(
                    db,
                    patient_id,
                    meds=meds_by_patient[patient_id],
                    user=users_by_id.get(patient_id),
                    subs=subs_by_user.get(patient_id, []),
                    fcm_tokens=fcm_by_user.get(patient_id, []),
                    links=links_by_patient.get(patient_id, []),
                    subs_by_user=subs_by_user,
                    fcm_by_user=fcm_by_user,
                )
            except Exception:
                logger.exception("reminder tick failed for patient %s", patient_id)
                db.rollback()

    return sent_count


def _tick_patient(
    db: Session,
    patient_id: str,
    *,
    meds: list[Medicine],
    user: User | None,
    subs: list[PushSubscription],
    fcm_tokens: list[FcmToken],
    links: list[CareLink],
    subs_by_user: dict[str, list[PushSubscription]],
    fcm_by_user: dict[str, list[FcmToken]],
) -> int:
    """Fire this patient's due doses across all three stages."""
    now = doses.local_now(_patient_timezone(user, subs))
    today = now.strftime("%Y-%m-%d")
    # Naive-UTC instant of the patient's local midnight: the boundary the
    # verify stage reads adherence against.
    day_start_utc = (
        now.replace(hour=0, minute=0, second=0, microsecond=0)
        .astimezone(dt_timezone.utc)
        .replace(tzinfo=None)
    )

    # (medicine, slot, stage) triples currently inside some stage window.
    # The stage follows from the slot's minute-delta alone, so each
    # (medicine, slot) lands in exactly one window per tick — including the
    # delta == VERIFY_MINUTES boundary, where the dose window wins and the
    # verify question waits for a later tick inside its own grace.
    due: list[tuple[Medicine, str, str]] = []
    for med in meds:
        if not doses.is_active_on(med, today):
            continue
        for t in doses.parse_times(med.taking_times):
            delta = _delta_minutes(t, now)
            if delta is None:
                continue
            stage = _stage_for(delta)
            if stage is None:
                continue
            due.append((med, t, stage))

    if not due:
        return 0

    recipients = recipients_for(patient_id, links)
    patient_name = user.name if user else "Your patient"

    sent = 0
    for med, slot, stage in due:
        mins = doses.minutes_of_day(slot)
        if mins is None:
            continue
        # The dose slot itself, in the patient's local zone — the send time may
        # drift up to GRACE_MINUTES later, but the slot identifies the dose.
        scheduled_for = datetime.combine(
            now.date(), datetime.min.time()
        ).replace(hour=mins // 60, minute=mins % 60)

        # The verification nag only asks when nobody has answered. Checked per
        # slot (not per recipient): one answer settles it for everyone, and a
        # settled slot claims no ledger rows at all.
        if stage == "verify" and _dose_settled(
            db, medicine_id=med.id, slot=slot, day_start_utc=day_start_utc
        ):
            continue

        for recipient in recipients:
            if not _eligible_for(
                db, recipient, medicine_id=med.id, scheduled_for=scheduled_for
            ):
                continue
            row = _claim(
                db,
                medicine_id=med.id,
                patient_id=patient_id,
                recipient_id=recipient.user_id,
                scheduled_for=scheduled_for,
                stage=stage,
            )
            if row is None:
                continue  # already delivered on an earlier tick
            if _deliver(
                db,
                subs_by_user.get(recipient.user_id, []),
                fcm_by_user.get(recipient.user_id, []),
                _payload(med, patient_name, slot, today, recipient, stage),
                row,
            ):
                sent += 1

    return sent


async def run_tick_once() -> int:
    """Run a single tick off the event loop. Used by the external-cron endpoint
    so a reliable scheduler (cron-job.org / UptimeRobot) can drive — and wake —
    a sleepy free-tier instance every minute."""
    return await asyncio.to_thread(_run_tick)


async def _loop() -> None:
    logger.info("Medicine reminder scheduler started")
    while True:
        try:
            await asyncio.to_thread(_run_tick)
        except Exception:
            logger.exception("reminder tick failed")
        await asyncio.sleep(_TICK_SECONDS)


_task: asyncio.Task | None = None


def start_scheduler() -> None:
    """Start the background loop if any push transport is configured. Safe once."""
    global _task
    if _task is not None:
        return
    if not reminders_available():
        logger.info("No push transport configured — reminder scheduler disabled")
        return
    _task = asyncio.create_task(_loop())


def stop_scheduler() -> None:
    global _task
    if _task is not None:
        _task.cancel()
        _task = None