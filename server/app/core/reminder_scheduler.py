"""Background scheduler that delivers medicine reminders via Web Push.

Runs once a minute. For every registered push subscription it computes the
user's LOCAL clock (from the subscription's timezone), finds medicines whose
`taking_times` match the current minute, and pushes a reminder — so the alarm
fires even when the app is completely closed.

Design notes:
  - One in-process asyncio task; the per-minute work runs in a worker thread so
    blocking DB/HTTP calls never stall the event loop.
  - Dedupe is in-memory, keyed per user+medicine+time+local-date, so a dose is
    pushed at most once a day even though we poll every minute. (A process
    restart can re-push a dose in the same minute — acceptable, and rare.)
  - Assumes a single worker process. With multiple workers you'd get duplicate
    pushes; run the scheduler in exactly one (or move dedupe to the DB).
"""

import asyncio
import json
import logging
from datetime import datetime

try:
    from zoneinfo import ZoneInfo
except Exception:  # pragma: no cover
    ZoneInfo = None  # type: ignore

from sqlmodel import Session, select

from app.core.config import engine, settings
from app.core.webpush import send_push, push_available
from app.models.models import Medicine, PushSubscription

logger = logging.getLogger("medicine_reminders")

_TICK_SECONDS = 60

# Fire a dose if its scheduled minute is within the last GRACE_MINUTES, not only
# the exact current minute. This is what makes reminders survive a free-tier
# instance that was asleep (or a delayed tick): when it wakes, it still delivers
# any dose due in the recent window instead of missing it forever. Dedupe keeps
# each dose to a single push per day, so the window never double-sends.
GRACE_MINUTES = 10

# { "YYYY-MM-DD": set("<user>:<med>:<HH:MM>") } — cleared as the date rolls over.
_sent: dict[str, set[str]] = {}


def _minutes_of_day(hhmm: str) -> int | None:
    try:
        h, m = hhmm.split(":")
        return int(h) * 60 + int(m)
    except Exception:
        return None


def _is_due(scheduled: str, now: datetime) -> bool:
    """True if `scheduled` (HH:MM) falls in [now - GRACE_MINUTES, now] today."""
    sched = _minutes_of_day(scheduled)
    if sched is None:
        return False
    now_min = now.hour * 60 + now.minute
    delta = now_min - sched
    return 0 <= delta <= GRACE_MINUTES


def _local_now(tz_name: str) -> datetime:
    if ZoneInfo is None:
        return datetime.utcnow()
    try:
        return datetime.now(ZoneInfo(tz_name or "UTC"))
    except Exception:
        return datetime.now(ZoneInfo("UTC"))


def _parse_times(taking_times) -> list[str]:
    if not taking_times:
        return []
    try:
        val = json.loads(taking_times)
        return [t for t in val if isinstance(t, str)] if isinstance(val, list) else []
    except Exception:
        return []


def _run_tick() -> int:
    """One synchronous pass over all subscriptions (runs in a worker thread).

    Returns the number of pushes sent — handy for the external-cron endpoint.
    """
    if not push_available():
        return 0

    sent_count = 0
    with Session(engine) as db:
        subs = db.exec(select(PushSubscription)).all()
        if not subs:
            return 0

        # Cache medicines per user so N subscriptions for one user hit the DB once.
        meds_by_user: dict[str, list[Medicine]] = {}
        dead: list[PushSubscription] = []

        for sub in subs:
            now = _local_now(sub.timezone)
            today = now.strftime("%Y-%m-%d")

            day_sent = _sent.setdefault(today, set())
            # Drop stale dedupe buckets (keep only today across all timezones is
            # fine — a few extra keys is cheaper than unbounded growth).
            for old in [d for d in _sent if d < today]:
                _sent.pop(old, None)

            if sub.user_id not in meds_by_user:
                meds_by_user[sub.user_id] = db.exec(
                    select(Medicine).where(Medicine.user_id == sub.user_id)
                ).all()

            for med in meds_by_user[sub.user_id]:
                if med.end_date and med.end_date < today:
                    continue
                if med.start_date and med.start_date > today:
                    continue
                for t in _parse_times(med.taking_times):
                    if not _is_due(t, now):
                        continue
                    key = f"{sub.user_id}:{med.id}:{t}:{today}"
                    if key in day_sent:
                        continue
                    payload = {
                        "title": "💊 Medicine Reminder",
                        "body": f"Time to take {med.name} ({med.dosage})",
                        "medId": med.id,
                        "name": med.name,
                        "dosage": med.dosage,
                        "time": t,
                        "tag": f"{med.id}-{t}-{today}",
                    }
                    result = send_push(sub.endpoint, sub.p256dh, sub.auth, payload)
                    if result.ok:
                        day_sent.add(key)
                        sent_count += 1
                    elif result.gone:
                        dead.append(sub)

        for sub in dead:
            try:
                db.delete(sub)
            except Exception:
                pass
        if dead:
            db.commit()

    return sent_count


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
