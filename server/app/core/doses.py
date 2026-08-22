"""Dose-schedule arithmetic, shared by the reminder scheduler and the care API.

A medicine's schedule is a JSON array of "HH:MM" clock strings in
`Medicine.taking_times`. Those are wall-clock times in the *patient's* local
zone, so every calculation here takes an explicit timezone rather than assuming
the server's.

`patient_timezone` centralises the timezone lookup. The patient's own
`User.timezone` column (set by the mobile app at sign-in) is preferred; when it
is unset the zone is inferred from the newest Web Push subscription the patient
registered. Callers don't reach into either table themselves.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta
from typing import Iterable, Optional

try:
    from zoneinfo import ZoneInfo
except Exception:  # pragma: no cover
    ZoneInfo = None  # type: ignore

from sqlmodel import Session, select

from app.models.models import Medicine, PushSubscription, User
from app.core.time import utcnow

DEFAULT_TZ = "UTC"

# Zone names Apple's web push reports that zoneinfo cannot load, mapped to the
# IANA equivalent. Mirrors app/api/push.py::canonical_timezone so old rows
# stored before that normalization existed still resolve to the right clock.
_TZ_ALIASES = {
    "Nepal Time": "Asia/Kathmandu",
    "Nepal Standard Time": "Asia/Kathmandu",
    "Asia/Katmandu": "Asia/Kathmandu",
}


def parse_times(taking_times: Optional[str]) -> list[str]:
    """The "HH:MM" entries of a medicine's schedule, or [] if unset/malformed."""
    if not taking_times:
        return []
    try:
        val = json.loads(taking_times)
    except Exception:
        return []
    return [t for t in val if isinstance(t, str)] if isinstance(val, list) else []


def minutes_of_day(hhmm: str) -> Optional[int]:
    try:
        h, m = hhmm.split(":")
        return int(h) * 60 + int(m)
    except Exception:
        return None


def zone(tz_name: Optional[str]):
    if ZoneInfo is None:
        return None
    name = _TZ_ALIASES.get(tz_name or "", tz_name)
    try:
        return ZoneInfo(name or DEFAULT_TZ)
    except Exception:
        return ZoneInfo(DEFAULT_TZ)


def local_now(tz_name: Optional[str]) -> datetime:
    tz = zone(tz_name)
    return datetime.now(tz) if tz else utcnow()


def timezone_from(user: Optional[User], newest_sub: Optional[PushSubscription]) -> str:
    """The zone-resolution rule itself, over rows the caller already holds.

    Split out from `patient_timezone` so a caller working across many patients
    can batch the two lookups and still apply exactly this rule — the reminder
    scheduler does, once per tick instead of twice per patient. Keeping the rule
    in one place is the point: a scheduler that resolved zones differently from
    the care API would fire reminders at times the UI never showed.
    """
    if user is not None and user.timezone:
        return user.timezone
    return newest_sub.timezone if newest_sub and newest_sub.timezone else DEFAULT_TZ


def patient_timezone(db: Session, patient_id: str) -> str:
    """The patient's IANA timezone, preferring their own column.

    `User.timezone` (set by the mobile app at sign-in) wins when present; it is
    the one the patient actually told the server. Otherwise the zone is inferred
    from the patient's newest push device, falling back to UTC when they have
    never registered one. This is the zone reminders fire in, for every
    recipient — a caretaker abroad is notified at the patient's dose time, not
    their own.

    Costs two queries for one patient. Across a set of patients, batch them and
    call `timezone_from` instead.
    """
    user = db.get(User, patient_id)
    if user is not None and user.timezone:
        return user.timezone

    sub = db.exec(
        select(PushSubscription)
        .where(PushSubscription.user_id == patient_id)
        .order_by(PushSubscription.created_at.desc())  # type: ignore[union-attr]
    ).first()
    return timezone_from(user, sub)


def is_active_on(med: Medicine, day: str) -> bool:
    """True if `med` is within its start/end window on ISO date `day`."""
    if med.deleted_at is not None:
        return False
    if med.start_date and med.start_date > day:
        return False
    if med.end_date and med.end_date < day:
        return False
    return True


def next_dose(
    medicines: Iterable[Medicine], now: datetime
) -> Optional[tuple[Medicine, datetime]]:
    """The soonest upcoming dose at or after `now`, searching today then tomorrow.

    `now` must already be in the patient's local zone. Returns the medicine and
    the local datetime of the slot, or None when nothing is scheduled.
    """
    meds = list(medicines)
    now_minutes = now.hour * 60 + now.minute

    for day_offset in (0, 1):
        day_date = (now + timedelta(days=day_offset)).date()
        day_iso = day_date.isoformat()
        best: Optional[tuple[Medicine, datetime]] = None

        for med in meds:
            if not is_active_on(med, day_iso):
                continue
            for t in parse_times(med.taking_times):
                mins = minutes_of_day(t)
                if mins is None:
                    continue
                if day_offset == 0 and mins < now_minutes:
                    continue
                slot = datetime.combine(day_date, datetime.min.time()).replace(
                    hour=mins // 60, minute=mins % 60, tzinfo=now.tzinfo
                )
                if best is None or slot < best[1]:
                    best = (med, slot)

        if best is not None:
            return best

    return None


def doses_on(med: Medicine, day: datetime) -> list[datetime]:
    """Every scheduled slot for `med` on the local date of `day`."""
    day_iso = day.date().isoformat()
    if not is_active_on(med, day_iso):
        return []

    slots: list[datetime] = []
    for t in parse_times(med.taking_times):
        mins = minutes_of_day(t)
        if mins is None:
            continue
        slots.append(
            datetime.combine(day.date(), datetime.min.time()).replace(
                hour=mins // 60, minute=mins % 60, tzinfo=day.tzinfo
            )
        )
    return sorted(slots)
