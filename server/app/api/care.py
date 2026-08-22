"""Care link endpoints: issue an invite code, redeem it, list, mute, revoke.

A caretaker is an ordinary user account. These endpoints only manage the
*relationship*; the access it grants is enforced in app/core/care.py and
applies to medicines alone.

The whole router 404s while CARETAKER_ENABLED is off, so the backend can ship
ahead of the UI without exposing a half-built feature.
"""

from datetime import datetime
from typing import List, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core import care, doses
from app.core.audit import record_access
from app.core.config import get_session, settings
from app.core.ratelimit import limiter, user_key
from app.core.time import utcnow
from app.models.models import CareInvite, CareLink, Medicine, User

router = APIRouter()


def require_enabled() -> None:
    """Hide the feature entirely while the flag is off."""
    if not settings.caretaker_enabled:
        raise HTTPException(status_code=404, detail="Not Found")


class InviteResponse(BaseModel):
    # The raw code, grouped XXXX-XXXX. Returned exactly once — only its hash is
    # stored, so it can never be retrieved again.
    code: str
    expires_at: str


class RedeemRequest(BaseModel):
    code: str


class CareLinkResponse(BaseModel):
    id: str
    user_id: str
    name: str
    created_at: str
    notify: bool
    # Populated for role=caretaker only: enough to render a client card without
    # a second round trip. Never includes anything outside the medicine scope.
    medicine_count: Optional[int] = None
    next_dose_name: Optional[str] = None
    # The patient's wall clock, e.g. "08:00" — deliberately not an instant, so
    # the caretaker's browser can't shift it into a different zone.
    next_dose_local: Optional[str] = None
    next_dose_is_today: Optional[bool] = None
    next_dose_timezone: Optional[str] = None


class CareLinksResponse(BaseModel):
    links: List[CareLinkResponse]


class NotifyUpdate(BaseModel):
    notify: bool


class MessageResponse(BaseModel):
    message: str


# --- Invites ---


@router.post("/invites", response_model=InviteResponse)
@limiter.limit("10/day", key_func=user_key)
async def create_invite(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Issue a fresh care code for the caller (acting as patient).

    Short-lived by design: this is meant to be read aloud or shown on screen to
    someone in the same room, not emailed.
    """
    require_enabled()

    active = care.active_links_for_patient(db, current_user.id)
    if len(active) >= care.MAX_CARETAKERS_PER_PATIENT:
        raise HTTPException(
            status_code=400,
            detail=(
                f"You already have {care.MAX_CARETAKERS_PER_PATIENT} caretakers, "
                f"the maximum. Remove one before adding another."
            ),
        )

    # Only the newest code should ever work.
    care.invalidate_outstanding_invites(db, current_user.id)

    code = care.generate_code()
    expires_at = utcnow() + care.INVITE_TTL
    db.add(
        CareInvite(
            patient_id=current_user.id,
            code_hash=care.hash_code(code),
            expires_at=expires_at,
        )
    )
    db.commit()
    record_access(
        db, "care.invite.created", actor_id=current_user.id, request=request
    )

    return InviteResponse(
        code=care.format_code(code), expires_at=care.utc_iso(expires_at)
    )


@router.post("/invites/redeem", response_model=CareLinkResponse)
@limiter.limit("5/hour", key_func=user_key)
@limiter.limit("20/hour")
async def redeem_invite(
    request: Request,
    data: RedeemRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Redeem a patient's code, becoming their caretaker.

    Wrong, expired and already-used codes all return one identical message so
    this can't be used as an oracle against the small code space. Self-redeem
    and already-linked are reported plainly — the caller already knows both
    facts, so there is nothing to leak.
    """
    require_enabled()

    invite = care.find_redeemable_invite(db, data.code)
    if invite is None:
        record_access(
            db, "care.redeem.failed", actor_id=current_user.id, request=request
        )
        raise HTTPException(status_code=400, detail=care.INVALID_CODE_MESSAGE)

    if invite.patient_id == current_user.id:
        raise HTTPException(
            status_code=400, detail="That's your own code — share it with someone else."
        )

    patient = db.get(User, invite.patient_id)
    if patient is None:
        raise HTTPException(status_code=400, detail=care.INVALID_CODE_MESSAGE)

    if care.fetch_active_care_link(
        db, patient_id=patient.id, caretaker_id=current_user.id
    ):
        raise HTTPException(
            status_code=400, detail=f"You're already a caretaker for {patient.name}."
        )

    if len(care.active_links_for_patient(db, patient.id)) >= care.MAX_CARETAKERS_PER_PATIENT:
        raise HTTPException(
            status_code=400,
            detail=f"{patient.name} already has the maximum number of caretakers.",
        )
    if len(care.active_links_for_caretaker(db, current_user.id)) >= care.MAX_CLIENTS_PER_CARETAKER:
        raise HTTPException(
            status_code=400,
            detail=(
                f"You're already caring for {care.MAX_CLIENTS_PER_CARETAKER} people, "
                f"the maximum."
            ),
        )

    link = CareLink(patient_id=patient.id, caretaker_id=current_user.id)
    invite.used_at = utcnow()
    invite.used_by = current_user.id
    db.add(link)
    db.add(invite)
    db.commit()
    db.refresh(link)

    record_access(
        db,
        "care.link.created",
        actor_id=current_user.id,
        subject_id=patient.id,
        resource_type="CareLink",
        resource_id=link.id,
        request=request,
    )

    from app.core.notify import notify_link_created

    notify_link_created(db, patient=patient, caretaker=current_user)

    return CareLinkResponse(
        id=link.id,
        user_id=patient.id,
        name=patient.name,
        created_at=care.utc_iso(link.created_at),
        notify=link.notify,
        **_client_summary(db, patient.id),
    )


# --- Listing ---


def _client_summary(db: Session, patient_id: str) -> dict:
    """Medicine count and next dose for a caretaker's client card.

    The dose time is reported as the patient's wall clock ("08:00"), not as an
    instant for the browser to localise. A caretaker in another country needs
    to know when *the patient* takes it; re-rendering that moment in the
    caretaker's own zone would show a time neither of them acts on.
    """
    meds = db.exec(
        select(Medicine).where(
            Medicine.user_id == patient_id,
            Medicine.deleted_at.is_(None),  # type: ignore[union-attr]
        )
    ).all()

    tz = doses.patient_timezone(db, patient_id)
    now = doses.local_now(tz)
    upcoming = doses.next_dose(meds, now)
    if upcoming is None:
        return {"medicine_count": len(meds)}

    med, slot = upcoming
    return {
        "medicine_count": len(meds),
        "next_dose_name": med.name,
        "next_dose_local": slot.strftime("%H:%M"),
        "next_dose_is_today": slot.date() == now.date(),
        "next_dose_timezone": tz,
    }


@router.get("/links", response_model=CareLinksResponse)
async def list_links(
    role: Literal["patient", "caretaker"] = "patient",
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """role=patient → who cares for me. role=caretaker → who I care for.

    Only the other party's display name is exposed. No email, no profile.
    """
    require_enabled()

    if role == "patient":
        links = care.active_links_for_patient(db, current_user.id)
        other_id = lambda link: link.caretaker_id  # noqa: E731
    else:
        links = care.active_links_for_caretaker(db, current_user.id)
        other_id = lambda link: link.patient_id  # noqa: E731

    out: List[CareLinkResponse] = []
    for link in sorted(links, key=lambda l: l.created_at, reverse=True):
        other = db.get(User, other_id(link))
        if other is None:
            continue
        extra = _client_summary(db, link.patient_id) if role == "caretaker" else {}
        out.append(
            CareLinkResponse(
                id=link.id,
                user_id=other.id,
                name=other.name,
                created_at=care.utc_iso(link.created_at),
                notify=link.notify,
                **extra,
            )
        )
    return CareLinksResponse(links=out)


# --- Mute / revoke ---


@router.patch("/links/{link_id}", response_model=CareLinkResponse)
async def update_link(
    link_id: str,
    data: NotifyUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Mute or unmute reminders for one client. Caretaker side only — a patient
    must not be able to silence their own caretaker's alerts."""
    require_enabled()

    link = db.get(CareLink, link_id)
    if not link or link.status != "active" or link.caretaker_id != current_user.id:
        raise HTTPException(status_code=404, detail="Care link not found")

    link.notify = data.notify
    db.add(link)
    db.commit()
    db.refresh(link)

    patient = db.get(User, link.patient_id)
    return CareLinkResponse(
        id=link.id,
        user_id=link.patient_id,
        name=patient.name if patient else "Unknown",
        created_at=care.utc_iso(link.created_at),
        notify=link.notify,
        **_client_summary(db, link.patient_id),
    )


@router.delete("/links/{link_id}", response_model=MessageResponse)
async def revoke_link(
    link_id: str,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Revoke a care link. Either party may do this, and it takes effect
    immediately: the next scheduler tick stops notifying, and the next medicine
    request from the caretaker 403s."""
    require_enabled()

    link = db.get(CareLink, link_id)
    if not link or link.status != "active":
        raise HTTPException(status_code=404, detail="Care link not found")
    if current_user.id not in (link.patient_id, link.caretaker_id):
        raise HTTPException(status_code=404, detail="Care link not found")

    link.status = "revoked"
    link.revoked_at = utcnow()
    link.revoked_by = current_user.id
    db.add(link)
    db.commit()

    record_access(
        db,
        "care.link.revoked",
        actor_id=current_user.id,
        subject_id=link.patient_id,
        resource_type="CareLink",
        resource_id=link.id,
        request=request,
    )

    # Tell the caretaker only when it was the patient who ended it; a caretaker
    # who removed a client doesn't need to be told what they just did.
    if current_user.id == link.patient_id:
        from app.core.notify import notify_link_revoked

        caretaker = db.get(User, link.caretaker_id)
        if caretaker:
            notify_link_revoked(db, patient=current_user, caretaker=caretaker)

    return MessageResponse(message="Care link removed")
