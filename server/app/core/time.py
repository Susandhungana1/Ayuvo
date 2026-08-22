"""Time helpers — one source of truth for 'right now in UTC'.

``datetime.utcnow()`` is deprecated since Python 3.12.  The replacement
``datetime.now(timezone.utc)`` returns a *timezone-aware* datetime, but
every column in the database is ``timestamp without time zone``.  Storing
an aware datetime into such a column strips the tzinfo, and comparing an
aware value against a naive one fetched from the DB raises ``TypeError``.

So we keep using naive UTC datetimes throughout the codebase (matching the
existing schema) and get there via:

    datetime.now(timezone.utc).replace(tzinfo=None)

This helper wraps that one-liner so callers don't repeat it.
"""

from datetime import datetime, timezone


def utcnow() -> datetime:
    """Return the current UTC time as a naive datetime (no tzinfo).

    Compatible with all existing ``timestamp without time zone`` columns
    while avoiding the ``datetime.utcnow()`` deprecation warning.
    """
    return datetime.now(timezone.utc).replace(tzinfo=None)
