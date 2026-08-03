"""One-off Web Push notices about care-link and medicine activity.

Separate from the reminder scheduler: those are recurring, deduplicated dose
alarms driven by a ledger, whereas these are single events fired inline from a
request handler. Both ride the same Web Push channel — this feature introduces
no new delivery mechanism.

Every function here is best-effort and never raises: failing to announce a link
change must not fail the request that caused it.
"""

from __future__ import annotations

import logging
from typing import Optional

from sqlmodel import Session, select

from app.core.webpush import push_available, send_push
from app.models.models import PushSubscription, User

logger = logging.getLogger("care_notify")


def _push_to_user(db: Session, user_id: str, payload: dict) -> int:
    """Fan a payload out to every device the user has registered."""
    if not push_available():
        return 0

    sent = 0
    subs = db.exec(
        select(PushSubscription).where(PushSubscription.user_id == user_id)
    ).all()
    for sub in subs:
        try:
            if send_push(sub.endpoint, sub.p256dh, sub.auth, payload).ok:
                sent += 1
        except Exception:  # pragma: no cover - defensive
            logger.exception("care notification failed")
    return sent


def notify_link_created(db: Session, *, patient: User, caretaker: User) -> None:
    """Tell the patient a caretaker just redeemed their code."""
    _push_to_user(
        db,
        patient.id,
        {
            "title": "Caretaker added",
            "body": f"{caretaker.name} is now a caretaker on your account.",
            "tag": f"care-link-{caretaker.id}",
            "kind": "care.link.created",
        },
    )


def notify_link_revoked(db: Session, *, patient: User, caretaker: User) -> None:
    """Tell the caretaker the patient ended the link."""
    _push_to_user(
        db,
        caretaker.id,
        {
            "title": "Caretaker access ended",
            "body": f"{patient.name} removed you as a caretaker.",
            "tag": f"care-revoke-{patient.id}",
            "kind": "care.link.revoked",
        },
    )


def notify_medicine_change(
    db: Session,
    *,
    patient: User,
    actor: User,
    action: str,
    medicine_name: str,
) -> None:
    """Tell the patient a caretaker added or removed one of their medicines.

    Silent when the patient is the actor — they just did it themselves.
    Updates are deliberately not announced: a caretaker correcting a dosage
    typo would otherwise be as loud as a deletion. The audit feed still records
    every change.
    """
    if actor.id == patient.id:
        return
    if action not in ("create", "delete"):
        return

    verb = "added" if action == "create" else "removed"
    _push_to_user(
        db,
        patient.id,
        {
            "title": "Medicine list updated",
            "body": f"{actor.name} {verb} {medicine_name}.",
            "tag": f"care-med-{action}-{medicine_name}",
            "kind": "care.medicine.changed",
        },
    )
