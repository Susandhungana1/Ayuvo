"""Caretaker access control and invite-code handling.

The single source of truth for "may this actor touch that patient's medicines".
Every medicine endpoint routes through `resolve_medicine_scope`; nothing else
is allowed to compare ids by hand, so there is exactly one place to audit.

Scope is deliberately narrow: a care link grants medicines and reminders, and
nothing else. Vitals, documents, reports and AI endpoints never accept a
patient_id and never consult this module.
"""

from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional

from fastapi import HTTPException
from sqlmodel import Session, select

from app.models.models import CareInvite, CareLink

# --- Invite codes ---

# Crockford base32 minus I, L, O and U: unambiguous when read aloud or copied
# off a screen, which is the whole delivery mechanism for these codes.
_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
CODE_LENGTH = 8
INVITE_TTL = timedelta(minutes=15)

# Caps. Small enough that the code space is never meaningfully searchable and
# that a compromised account can't quietly accumulate dependents.
MAX_CARETAKERS_PER_PATIENT = 5
MAX_CLIENTS_PER_CARETAKER = 15

# One generic message for wrong / expired / already-used codes alike, so the
# endpoint can't be used as an oracle to distinguish them.
INVALID_CODE_MESSAGE = "That code isn't valid. Ask for a new one."


def generate_code() -> str:
    """A fresh 8-character code. Uses `secrets`, never `random`."""
    return "".join(secrets.choice(_ALPHABET) for _ in range(CODE_LENGTH))


def format_code(code: str) -> str:
    """Group as XXXX-XXXX for display."""
    return f"{code[:4]}-{code[4:]}"


def normalize_code(raw: str) -> str:
    """Uppercase and strip dashes/whitespace so a pasted 4k7m-9qx2 still works."""
    return "".join(ch for ch in (raw or "").upper() if ch.isalnum())


def hash_code(code: str) -> str:
    """SHA-256 of the normalized code. Raw codes are never stored."""
    return hashlib.sha256(normalize_code(code).encode()).hexdigest()


def utc_iso(value: datetime) -> str:
    """Serialize a naive-UTC column as an explicitly-UTC ISO string.

    Timestamps are stored via datetime.utcnow(), so they carry no offset. Sent
    bare, `Date.parse` in the browser reads them as *local* time: in Kathmandu
    (UTC+5:45) a code that expires in 15 minutes renders as already expired.
    The trailing Z is what makes the client agree with the server.
    """
    return value.isoformat() + "Z"


# --- Link lookup ---


def fetch_active_care_link(
    db: Session, *, patient_id: str, caretaker_id: str
) -> Optional[CareLink]:
    return db.exec(
        select(CareLink).where(
            CareLink.patient_id == patient_id,
            CareLink.caretaker_id == caretaker_id,
            CareLink.status == "active",
        )
    ).first()


def active_links_for_patient(db: Session, patient_id: str) -> list[CareLink]:
    """Every active caretaker of this patient (used by the reminder fan-out)."""
    return list(
        db.exec(
            select(CareLink).where(
                CareLink.patient_id == patient_id,
                CareLink.status == "active",
            )
        ).all()
    )


def active_links_for_caretaker(db: Session, caretaker_id: str) -> list[CareLink]:
    return list(
        db.exec(
            select(CareLink).where(
                CareLink.caretaker_id == caretaker_id,
                CareLink.status == "active",
            )
        ).all()
    )


# --- The authorization rule ---


def resolve_medicine_scope(
    db: Session, *, actor_id: str, patient_id: Optional[str]
) -> str:
    """Return the patient id whose medicines `actor_id` may operate on.

    `patient_id` omitted means "my own medicines", which is what every
    pre-caretaker caller does — so existing patient behaviour is unchanged.
    Raises 403 when the actor has no active care link to the requested patient.

    The caller must pass patient_id from a validated query/path parameter only.
    Never from a request body: a body-supplied id would let a caretaker aim a
    write at an arbitrary account.
    """
    # An empty (rather than absent) patient_id means the caller meant to scope
    # to someone and the value was lost in transit. User ids contain a '#', so
    # a URL built without percent-encoding truncates it into a fragment and the
    # parameter arrives blank. Falling through to "my own medicines" there would
    # silently write a caretaker's edit onto their own list, so refuse instead.
    if patient_id is not None and not patient_id.strip():
        raise HTTPException(400, "patient_id was supplied but empty")

    target = patient_id or actor_id
    if target == actor_id:
        return target

    # While the flag is off, no cross-account access exists at all — even for a
    # link left in the database by an earlier enabled run.
    from app.core.config import settings

    if not settings.caretaker_enabled:
        raise HTTPException(403, "No active care link for this patient")

    if not fetch_active_care_link(db, patient_id=target, caretaker_id=actor_id):
        raise HTTPException(403, "No active care link for this patient")
    return target


# --- Invite lifecycle ---


def find_redeemable_invite(db: Session, code: str) -> Optional[CareInvite]:
    """Look up an unused, unexpired invite by code hash, or None.

    Returns None for all failure modes so the caller emits one generic error.
    """
    invite = db.exec(
        select(CareInvite).where(CareInvite.code_hash == hash_code(code))
    ).first()
    if not invite or invite.used_at is not None:
        return None
    if invite.expires_at < datetime.utcnow():
        return None
    return invite


def invalidate_outstanding_invites(db: Session, patient_id: str) -> None:
    """Burn any unused invite from this patient, so only the newest code works."""
    now = datetime.utcnow()
    for old in db.exec(
        select(CareInvite).where(
            CareInvite.patient_id == patient_id,
            CareInvite.used_at.is_(None),  # type: ignore[union-attr]
        )
    ).all():
        old.used_at = now
        db.add(old)
