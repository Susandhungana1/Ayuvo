"""Background scheduler that delivers medicine reminders via Web Push.

Runs once a minute. For every patient with medicines it computes their LOCAL
clock, finds doses due in the recent window, and pushes a reminder to the
patient and to each of their active caretakers — so the alarm fires even when
the app is completely closed.

Design notes:
  - One in-process asyncio task; the per-minute work runs in a worker thread so
    blocking DB/HTTP calls never stall the event loop.
  - The loop is driven by PATIENTS, not by push subscriptions. A dose belongs
    to a patient and resolves in the patient's timezone; recipients are derived
    from it. A caretaker in another zone is therefore notified at the patient's
    dose time, not shifted into their own.
  - Dedupe lives in the reminder_deliveries table, keyed by
    (medicine, recipient, dose slot, channel). That survives restarts — the
    previous in-memory set did not — and it also means a caretaker who links
    mid-day is never backfilled with slots that already passed.
  - Safe with multiple workers: a duplicate insert loses the unique-constraint
    race and is skipped rather than sent twice.
"""

import asyncio
import logging
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy.exc import IntegrityError
from sqlmodel import Session, select

from app.core import doses
from app.core.care import active_links_for_patient
from app.core.config import engine, settings
from app.core.webpush import push_available, send_push
from app.models.models import Medicine, PushSubscription, ReminderDelivery

logger = logging.getLogger("medicine_reminders")

_TICK_SECONDS = 60

# Fire a dose if its scheduled minute is within the last GRACE_MINUTES, not only
# the exact current minute. This is what makes reminders survive a free-tier
# instance that was asleep (or a delayed tick): when it wakes, it still delivers
# any dose due in the recent window instead of missing it forever. The delivery
# ledger keeps each dose to a single push, so the window never double-sends.
GRACE_MINUTES = 10

CHANNEL = "webpush"


@dataclass(frozen=True)
class Recipient:
    user_id: str
    is_self: bool
    # When the care link was created (UTC), for caretakers only. A dose slot
    # that predates it is not theirs to hear about — see _eligible_for.
    linked_at: datetime | None = None


def _is_due(scheduled: str, now: datetime) -> bool:
    """True if `scheduled` (HH:MM) falls in [now - GRACE_MINUTES, now] today."""
    sched = doses.minutes_of_day(scheduled)
    if sched is None:
        return False
    now_min = now.hour * 60 + now.minute
    delta = now_min - sched
    return 0 <= delta <= GRACE_MINUTES


def recipients_for(db: Session, patient_id: str) -> list[Recipient]:
    """The patient, plus every caretaker who hasn't muted them.

    With no care links this is just [patient] — byte-for-byte the behaviour
    before the feature existed.
    """
    out = [Recipient(user_id=patient_id, is_self=True)]
    if not settings.caretaker_enabled:
        return out

    for link in active_links_for_patient(db, patient_id):
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
) -> ReminderDelivery | None:
    """Reserve this (dose slot, recipient) pair, or None if already delivered.

    The unique constraint is the arbiter: whoever inserts first owns the send.
    A loser rolls back and skips, which is what makes repeated ticks — and
    concurrent workers — idempotent.
    """
    row = ReminderDelivery(
        medicine_id=medicine_id,
        patient_id=patient_id,
        recipient_id=recipient_id,
        scheduled_for=scheduled_for,
        channel=CHANNEL,
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


def _deliver(
    db: Session, recipient: Recipient, payload: dict, row: ReminderDelivery
) -> bool:
    """Push to every device the recipient has, recording the outcome.

    A failure for one recipient never aborts the others: the exception is
    captured onto their own ledger row and the loop moves on.
    """
    subs = db.exec(
        select(PushSubscription).where(PushSubscription.user_id == recipient.user_id)
    ).all()
    if not subs:
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
                # 404/410 — the browser dropped this subscription for good.
                try:
                    db.delete(sub)
                except Exception:
                    pass

    row.status = "sent" if sent else "failed"
    row.error = None if sent else "; ".join(errors)[:500]
    db.add(row)
    db.commit()
    return sent


def _payload(med: Medicine, patient_name: str, slot: str, day: str, recipient: Recipient) -> dict:
    """Reminder copy. A caretaker may be watching several people at once, so
    theirs always leads with the patient's name — otherwise two clients'
    reminders are indistinguishable."""
    if recipient.is_self:
        title = "💊 Medicine Reminder"
        body = f"Time for {med.name} {med.dosage}"
    else:
        title = f"💊 {patient_name}"
        body = f"{patient_name} — {med.name} {med.dosage} due now"

    return {
        "title": title,
        "body": body,
        "medId": med.id,
        "name": med.name,
        "dosage": med.dosage,
        "time": slot,
        "tag": f"{med.id}-{slot}-{day}-{recipient.user_id}",
        "forSelf": recipient.is_self,
    }


def _run_tick() -> int:
    """One synchronous pass over all patients (runs in a worker thread).

    Returns the number of pushes sent — handy for the external-cron endpoint.
    """
    if not push_available():
        return 0

    sent_count = 0
    with Session(engine) as db:
        # Patients are those who own medicines. Anyone without medicines has
        # nothing to fire, caretaker or not.
        patient_ids = {
            row for row in db.exec(
                select(Medicine.user_id).where(
                    Medicine.deleted_at.is_(None)  # type: ignore[union-attr]
                )
            ).all()
        }

        for patient_id in patient_ids:
            try:
                sent_count += _tick_patient(db, patient_id)
            except Exception:
                logger.exception("reminder tick failed for patient %s", patient_id)
                db.rollback()

    return sent_count


def _tick_patient(db: Session, patient_id: str) -> int:
    from app.models.models import User

    tz = doses.patient_timezone(db, patient_id)
    now = doses.local_now(tz)
    today = now.strftime("%Y-%m-%d")

    meds = db.exec(
        select(Medicine).where(
            Medicine.user_id == patient_id,
            Medicine.deleted_at.is_(None),  # type: ignore[union-attr]
        )
    ).all()
    due: list[tuple[Medicine, str]] = [
        (med, t)
        for med in meds
        if doses.is_active_on(med, today)
        for t in doses.parse_times(med.taking_times)
        if _is_due(t, now)
    ]
    if not due:
        return 0

    recipients = recipients_for(db, patient_id)
    patient = db.get(User, patient_id)
    patient_name = patient.name if patient else "Your patient"

    sent = 0
    for med, slot in due:
        mins = doses.minutes_of_day(slot)
        if mins is None:
            continue
        # The dose slot itself, in the patient's local zone — the send time may
        # be up to GRACE_MINUTES later, but the slot is what identifies it.
        scheduled_for = datetime.combine(
            now.date(), datetime.min.time()
        ).replace(hour=mins // 60, minute=mins % 60)

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
            )
            if row is None:
                continue  # already delivered on an earlier tick
            if _deliver(
                db, recipient, _payload(med, patient_name, slot, today, recipient), row
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
    """Start the background loop if push is configured. Safe to call once."""
    global _task
    if _task is not None:
        return
    if not settings.push_enabled:
        logger.info("Push not configured — reminder scheduler disabled")
        return
    _task = asyncio.create_task(_loop())


def stop_scheduler() -> None:
    global _task
    if _task is not None:
        _task.cancel()
        _task = None
