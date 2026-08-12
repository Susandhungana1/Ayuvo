from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import String, cast, func, literal, select as sa_select, union_all
from sqlmodel import Session

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


# The relative order tables were appended in, before the Python sort. Because
# the sort is stable, events with identical dates come back in this order; the
# SQL ORDER BY carries it as a tie-break so the response is identical.
_TYPE_RANK = {
    "report": 0,
    "medicine": 1,
    "appointment": 2,
    "vital": 3,
}


def _timeline_union(user_id: str):
    """A UNION ALL of the four tables, projected onto one wide row.

    Every branch exposes the same columns; fields a table does not use are
    NULL. `sort_key` is the column the response's `date` string comes from, so
    ordering by it in SQL is ordering by the same thing Python used to sort.
    """
    reports = (
        sa_select(
            literal("report").label("type"),
            MedicalReport.id.label("id"),
            MedicalReport.file_name.label("title_col"),
            MedicalReport.notes.label("desc_col1"),
            MedicalReport.result_summary.label("desc_col2"),
            cast(literal(None), String).label("status_col"),
            cast(literal(None), String).label("bp_sys"),
            cast(literal(None), String).label("bp_dia"),
            cast(literal(None), String).label("hr"),
            cast(literal(None), String).label("weight"),
            cast(literal(None), String).label("bs"),
            cast(literal(None), String).label("temp"),
            cast(literal(None), String).label("spo2"),
            MedicalReport.created_at.label("sort_key"),
            literal(_TYPE_RANK["report"]).label("type_rank"),
        )
        .where(MedicalReport.user_id == user_id)
    )
    medicines = (
        sa_select(
            literal("medicine").label("type"),
            Medicine.id.label("id"),
            Medicine.name.label("title_col"),
            Medicine.dosage.label("desc_col1"),
            Medicine.frequency.label("desc_col2"),
            cast(literal(None), String).label("status_col"),
            cast(literal(None), String).label("bp_sys"),
            cast(literal(None), String).label("bp_dia"),
            cast(literal(None), String).label("hr"),
            cast(literal(None), String).label("weight"),
            cast(literal(None), String).label("bs"),
            cast(literal(None), String).label("temp"),
            cast(literal(None), String).label("spo2"),
            Medicine.created_at.label("sort_key"),
            literal(_TYPE_RANK["medicine"]).label("type_rank"),
        )
        .where(Medicine.user_id == user_id)
    )
    appointments = (
        sa_select(
            literal("appointment").label("type"),
            Appointment.id.label("id"),
            Appointment.title.label("title_col"),
            Appointment.doctor_name.label("desc_col1"),
            Appointment.hospital.label("desc_col2"),
            cast(Appointment.status, String).label("status_col"),
            cast(literal(None), String).label("bp_sys"),
            cast(literal(None), String).label("bp_dia"),
            cast(literal(None), String).label("hr"),
            cast(literal(None), String).label("weight"),
            cast(literal(None), String).label("bs"),
            cast(literal(None), String).label("temp"),
            cast(literal(None), String).label("spo2"),
            Appointment.created_at.label("sort_key"),
            literal(_TYPE_RANK["appointment"]).label("type_rank"),
        )
        .where(Appointment.user_id == user_id)
    )
    vitals = (
        sa_select(
            literal("vital").label("type"),
            VitalSign.id.label("id"),
            cast(literal(None), String).label("title_col"),
            VitalSign.notes.label("desc_col1"),
            cast(literal(None), String).label("desc_col2"),
            cast(literal(None), String).label("status_col"),
            cast(VitalSign.blood_pressure_systolic, String).label("bp_sys"),
            cast(VitalSign.blood_pressure_diastolic, String).label("bp_dia"),
            cast(VitalSign.heart_rate, String).label("hr"),
            cast(VitalSign.weight, String).label("weight"),
            cast(VitalSign.blood_sugar, String).label("bs"),
            cast(VitalSign.temperature, String).label("temp"),
            cast(VitalSign.oxygen_saturation, String).label("spo2"),
            func.coalesce(VitalSign.measured_at, VitalSign.created_at).label("sort_key"),
            literal(_TYPE_RANK["vital"]).label("type_rank"),
        )
        .where(VitalSign.user_id == user_id)
    )
    return union_all(reports, medicines, appointments, vitals)


def _event(row) -> TimelineEvent:
    parts = []
    if row.bp_sys and row.bp_dia:
        parts.append(f"BP: {row.bp_sys}/{row.bp_dia}")
    if row.hr:
        parts.append(f"HR: {row.hr}")
    if row.weight:
        parts.append(f"Weight: {row.weight}kg")
    if row.bs:
        parts.append(f"BS: {row.bs}")
    if row.temp:
        parts.append(f"Temp: {row.temp}°C")
    if row.spo2:
        parts.append(f"SpO2: {row.spo2}%")

    if row.type == "report":
        title = f"Report: {row.title_col}"
        description = row.desc_col1 or row.desc_col2
    elif row.type == "medicine":
        title = f"Medicine: {row.title_col}"
        description = f"{row.desc_col1} - {row.desc_col2}"
    elif row.type == "appointment":
        title = f"Appointment: {row.title_col}"
        description = (
            f"{row.desc_col1 or 'Doctor'} at {row.desc_col2 or 'Hospital'}"
            f" - {row.status_col}"
        )
    else:
        title = "Vitals Check"
        description = ", ".join(parts) or row.desc_col1

    return TimelineEvent(
        type=row.type,
        id=row.id,
        title=title,
        description=description,
        date=str(row.sort_key),
    )


@router.get("", response_model=TimelineResponse)
async def get_timeline(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
):
    # The slice happens in SQL: only the page rows cross the wire, instead of
    # loading the whole account and slicing the merged list in Python (which
    # re-read everything on every "Show older" tap).
    union = _timeline_union(current_user.id).subquery()

    page = db.exec(
        sa_select(union)
        .order_by(union.c.sort_key.desc(), union.c.type_rank.asc())
        .offset(offset)
        .limit(limit)
    ).all()

    # total is the pre-slice count, exactly what the old Python built from
    # len(events). Counted in SQL on the same union.
    total = db.exec(sa_select(func.count()).select_from(union)).one()[0]

    return TimelineResponse(events=[_event(row) for row in page], total=total)
