from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.config import get_session
from app.models.models import User, MedicalReport, Medicine, Appointment, VitalSign

router = APIRouter()


class TimelineEvent(BaseModel):
    type: str
    id: str
    title: str
    description: Optional[str]
    date: str


class TimelineResponse(BaseModel):
    events: List[TimelineEvent]
    total: int


@router.get("", response_model=TimelineResponse)
async def get_timeline(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
):
    events = []

    reports = db.exec(
        select(MedicalReport)
        .where(MedicalReport.user_id == current_user.id)
        .order_by(MedicalReport.created_at.desc())
    ).all()

    for r in reports:
        events.append(TimelineEvent(
            type="report",
            id=r.id,
            title=f"Report: {r.file_name}",
            description=r.notes or r.result_summary,
            date=str(r.created_at) if r.created_at else "",
        ))

    medicines = db.exec(
        select(Medicine)
        .where(Medicine.user_id == current_user.id)
        .order_by(Medicine.created_at.desc())
    ).all()

    for m in medicines:
        events.append(TimelineEvent(
            type="medicine",
            id=m.id,
            title=f"Medicine: {m.name}",
            description=f"{m.dosage} - {m.frequency}",
            date=str(m.created_at) if m.created_at else "",
        ))

    appointments = db.exec(
        select(Appointment)
        .where(Appointment.user_id == current_user.id)
        .order_by(Appointment.created_at.desc())
    ).all()

    for a in appointments:
        events.append(TimelineEvent(
            type="appointment",
            id=a.id,
            title=f"Appointment: {a.title}",
            description=f"{a.doctor_name or 'Doctor'} at {a.hospital or 'Hospital'} - {a.status.value if hasattr(a.status, 'value') else a.status}",
            date=str(a.created_at) if a.created_at else "",
        ))

    vitals = db.exec(
        select(VitalSign)
        .where(VitalSign.user_id == current_user.id)
        .order_by(VitalSign.created_at.desc())
    ).all()

    for v in vitals:
        parts = []
        if v.blood_pressure_systolic and v.blood_pressure_diastolic:
            parts.append(f"BP: {v.blood_pressure_systolic}/{v.blood_pressure_diastolic}")
        if v.heart_rate:
            parts.append(f"HR: {v.heart_rate}")
        if v.weight:
            parts.append(f"Weight: {v.weight}kg")
        if v.blood_sugar:
            parts.append(f"BS: {v.blood_sugar}")
        if v.temperature:
            parts.append(f"Temp: {v.temperature}°C")
        if v.oxygen_saturation:
            parts.append(f"SpO2: {v.oxygen_saturation}%")

        events.append(TimelineEvent(
            type="vital",
            id=v.id,
            title="Vitals Check",
            description=", ".join(parts) or v.notes,
            date=str(v.measured_at) if v.measured_at else str(v.created_at),
        ))

    events.sort(key=lambda e: e.date, reverse=True)

    paginated = events[offset:offset + limit]

    return TimelineResponse(events=paginated, total=len(events))
