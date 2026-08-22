from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.config import get_session
from app.core.audit import record_access
from app.core.ratelimit import limiter
from app.core.time import utcnow
from app.models.models import User, EmergencyContact

router = APIRouter()


class EmergencyProfileResponse(BaseModel):
    name: Optional[str] = None
    blood_type: Optional[str]
    emergency_contacts: List["EmergencyContactResponse"]


class EmergencyContactCreate(BaseModel):
    name: str
    phone: str


class EmergencyContactResponse(BaseModel):
    id: str
    name: str
    phone: str


@router.get("/profile", response_model=EmergencyProfileResponse)
async def get_emergency_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    contacts = db.exec(
        select(EmergencyContact)
        .where(EmergencyContact.user_id == current_user.id)
    ).all()

    return EmergencyProfileResponse(
        name=current_user.name,
        blood_type=current_user.blood_type,
        emergency_contacts=[
            EmergencyContactResponse(
                id=c.id,
                name=c.name,
                phone=c.phone,
            )
            for c in contacts
        ],
    )


class EmergencyProfileUpdate(BaseModel):
    blood_type: Optional[str] = None


@router.put("/profile", response_model=EmergencyProfileResponse)
async def update_emergency_profile(
    data: EmergencyProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    if data.blood_type is not None:
        current_user.blood_type = data.blood_type
    current_user.updated_at = utcnow()

    db.add(current_user)
    db.commit()
    db.refresh(current_user)

    contacts = db.exec(
        select(EmergencyContact)
        .where(EmergencyContact.user_id == current_user.id)
    ).all()

    return EmergencyProfileResponse(
        name=current_user.name,
        blood_type=current_user.blood_type,
        emergency_contacts=[
            EmergencyContactResponse(
                id=c.id,
                name=c.name,
                phone=c.phone,
            )
            for c in contacts
        ],
    )


@router.post("/contacts", response_model=EmergencyContactResponse)
async def create_emergency_contact(
    data: EmergencyContactCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    contact = EmergencyContact(
        user_id=current_user.id,
        name=data.name,
        phone=data.phone,
    )
    db.add(contact)
    db.commit()
    db.refresh(contact)
    return EmergencyContactResponse(
        id=contact.id,
        name=contact.name,
        phone=contact.phone,
    )


@router.delete("/contacts/{contact_id}")
async def delete_emergency_contact(
    contact_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    contact = db.get(EmergencyContact, contact_id)
    if not contact or contact.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Contact not found")
    db.delete(contact)
    db.commit()
    return {"message": "Contact deleted"}


@router.get("/public/{user_id}", response_model=EmergencyProfileResponse)
@limiter.limit("5/hour")
async def get_public_emergency_profile(
    request: Request,
    user_id: str,
    db: Session = Depends(get_session),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    record_access(
        db, "emergency.view",
        subject_id=user_id, resource_type="User", resource_id=user_id,
        request=request,
    )

    contacts = db.exec(
        select(EmergencyContact)
        .where(EmergencyContact.user_id == user_id)
    ).all()

    # This endpoint is unauthenticated and user ids are sequential, so it is a
    # scrape target. It must stay minimal: no third-party email addresses, no
    # account ids — just the fields a paramedic needs. The owner's own signed-in
    # profile (`GET /api/emergency/profile`) still returns everything.
    return EmergencyProfileResponse(
        name=user.name,
        blood_type=user.blood_type,
        emergency_contacts=[
            EmergencyContactResponse(
                id="",
                name=c.name,
                phone=c.phone,
            )
            for c in contacts
        ],
    )
