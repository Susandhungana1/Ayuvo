from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, field_validator
from sqlmodel import Session, select

from app.api.auth import get_current_user, get_session
from app.core import storage
from app.models.models import (
    User, PasswordResetToken, RefreshToken, Doctor, DoctorAvailability,
    MedicalDocument, MedicalFile, Medicine, MedicineIntakeLog, PushSubscription,
    MedicalReport, Appointment, ShareLink, VitalSign, EmergencyContact,
    AuditLog, CareInvite, CareLink, MedicineAudit, ReminderDelivery,
    ClaimedShare,
)

router = APIRouter()


class UserUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    # IANA timezone (e.g. "Asia/Kathmandu"), sent by the mobile app at sign-in.
    # Optional and unset by default; an empty string means "unset".
    timezone: Optional[str] = None

    @field_validator("timezone")
    @classmethod
    def _blank_timezone_is_none(cls, v: Optional[str]) -> Optional[str]:
        return v.strip() if isinstance(v, str) and v.strip() else None


class UserDetail(BaseModel):
    id: str
    name: str
    email: str
    role: str
    address: Optional[str] = None
    city: Optional[str] = None
    timezone: Optional[str] = None


@router.get("/me", response_model=UserDetail)
async def get_current_user_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    return UserDetail(
        id=current_user.id,
        name=current_user.name,
        email=current_user.email,
        role=current_user.role,
        address=current_user.address,
        city=current_user.city,
        timezone=current_user.timezone
    )


@router.put("/me", response_model=UserDetail)
async def update_current_user(
    user_data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    if user_data.name:
        current_user.name = user_data.name
    if user_data.address:
        current_user.address = user_data.address
    if user_data.city:
        current_user.city = user_data.city
    if user_data.latitude is not None:
        current_user.latitude = user_data.latitude
    if user_data.longitude is not None:
        current_user.longitude = user_data.longitude
    if "timezone" in user_data.model_fields_set:
        current_user.timezone = user_data.timezone

    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    
    return UserDetail(
        id=current_user.id,
        name=current_user.name,
        email=current_user.email,
        role=current_user.role,
        address=current_user.address,
        city=current_user.city,
        timezone=current_user.timezone
    )


def _wipe_stored_files(db: Session, user_id: str) -> None:
    """Delete object-storage blobs for the user's reports and document files
    before the DB rows go, so storage does not leak after the account does."""
    for report in db.exec(
        select(MedicalReport).where(MedicalReport.user_id == user_id)
    ).all():
        if report.storage_key:
            try:
                storage.delete_file(report.storage_key)
            except Exception:
                pass
    for doc in db.exec(
        select(MedicalDocument).where(MedicalDocument.user_id == user_id)
    ).all():
        for file in db.exec(select(MedicalFile).where(MedicalFile.document_id == doc.id)).all():
            if file.storage_key:
                try:
                    storage.delete_file(file.storage_key)
                except Exception:
                    pass


@router.delete("/me", status_code=status.HTTP_200_OK)
async def delete_current_user(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    """Permanently delete the account and every row that belongs to it.

    Covers the user's own data (reports, documents, vitals, medicines,
    appointments, emergency profile, push subscriptions, refresh tokens), the
    caretaker graph (links they issued or redeemed, medicine audit, queued
    deliveries) and claimed shares on both sides. Audit log rows referencing
    the user are removed too — the GDPR-style right to erasure wins over the
    access trail here. Object-storage blobs are deleted before the DB rows.
    """
    user_id = current_user.id

    _wipe_stored_files(db, user_id)

    doc_ids = [d.id for d in db.exec(
        select(MedicalDocument).where(MedicalDocument.user_id == user_id)
    ).all()]

    for table in [MedicalReport, Appointment, ShareLink,
                  VitalSign, EmergencyContact, MedicineIntakeLog,
                  Medicine, PushSubscription, MedicalDocument]:
        rows = db.exec(
            select(table).where(table.user_id == user_id)
        ).all()
        for row in rows:
            db.delete(row)

    for doc_id in doc_ids:
        for row in db.exec(select(MedicalFile).where(MedicalFile.document_id == doc_id)).all():
            db.delete(row)

    doctor = db.exec(select(Doctor).where(Doctor.user_id == user_id)).first()
    if doctor:
        for row in db.exec(
            select(DoctorAvailability).where(DoctorAvailability.doctor_id == doctor.id)
        ).all():
            db.delete(row)
        db.delete(doctor)

    for row in db.exec(select(CareInvite).where(CareInvite.patient_id == user_id)).all():
        db.delete(row)
    for row in db.exec(
        select(CareLink).where(
            (CareLink.patient_id == user_id) | (CareLink.caretaker_id == user_id)
        )
    ).all():
        db.delete(row)
    for row in db.exec(select(MedicineAudit).where(MedicineAudit.patient_id == user_id)).all():
        db.delete(row)
    for row in db.exec(
        select(ReminderDelivery).where(
            (ReminderDelivery.recipient_id == user_id)
            | (ReminderDelivery.patient_id == user_id)
        )
    ).all():
        db.delete(row)
    for row in db.exec(
        select(ClaimedShare).where(
            (ClaimedShare.recipient_id == user_id) | (ClaimedShare.owner_id == user_id)
        )
    ).all():
        db.delete(row)
    for row in db.exec(
        select(AuditLog).where(
            (AuditLog.actor_id == user_id) | (AuditLog.subject_id == user_id)
        )
    ).all():
        db.delete(row)
    for row in db.exec(
        select(PasswordResetToken).where(PasswordResetToken.user_id == user_id)
    ).all():
        db.delete(row)
    for row in db.exec(
        select(RefreshToken).where(RefreshToken.user_id == user_id)
    ).all():
        db.delete(row)

    db.delete(current_user)
    db.commit()
    return {"message": "Account deleted"}