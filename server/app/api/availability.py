from datetime import time
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, field_validator
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.config import get_session
from app.models.models import User, Doctor, DoctorAvailability, DayOfWeek

router = APIRouter()


class AvailabilityCreate(BaseModel):
    day_of_week: DayOfWeek
    start_time: time
    end_time: time
    slot_duration_minutes: int = 30
    is_available: bool = True

    @field_validator("end_time")
    @classmethod
    def end_after_start(cls, v: time, info) -> time:
        start = info.data.get("start_time")
        if start is not None and v <= start:
            raise ValueError("end_time must be after start_time")
        return v


class AvailabilityUpdate(BaseModel):
    day_of_week: Optional[DayOfWeek] = None
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    slot_duration_minutes: Optional[int] = None
    is_available: Optional[bool] = None


class AvailabilityResponse(BaseModel):
    id: str
    day_of_week: str
    start_time: time
    end_time: time
    slot_duration_minutes: int
    is_available: bool


class AvailabilityListResponse(BaseModel):
    availability: List[AvailabilityResponse]


class DoctorCreate(BaseModel):
    nmid: str
    degree: str
    specialty: Optional[str] = None


class DoctorResponse(BaseModel):
    id: str
    nmid: str
    degree: str
    specialty: Optional[str]
    verified: bool
    user_id: str
    name: str


class DoctorListResponse(BaseModel):
    doctors: List[DoctorResponse]


def _require_doctor_role(user: User) -> None:
    if user.role != "DOCTOR" and user.role != "ADMIN":
        raise HTTPException(
            status_code=403,
            detail="Only doctors or admins can access this resource"
        )


@router.post("/doctors", response_model=DoctorResponse)
async def create_doctor(
    doctor_data: DoctorCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    _require_doctor_role(current_user)

    existing = db.exec(select(Doctor).where(Doctor.user_id == current_user.id)).first()
    if existing:
        raise HTTPException(status_code=400, detail="Doctor profile already exists")

    doctor = Doctor(
        nmid=doctor_data.nmid,
        degree=doctor_data.degree,
        specialty=doctor_data.specialty,
        user_id=current_user.id
    )
    db.add(doctor)
    db.commit()
    db.refresh(doctor)

    return DoctorResponse(
        id=doctor.id,
        nmid=doctor.nmid,
        degree=doctor.degree,
        specialty=doctor.specialty,
        verified=doctor.verified,
        user_id=doctor.user_id,
        name=current_user.name
    )


@router.get("/doctors", response_model=DoctorListResponse)
async def list_doctors(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    doctors = db.exec(select(Doctor).where(Doctor.verified == True)).all()

    user_ids = [d.user_id for d in doctors]
    users = db.exec(select(User).where(User.id.in_(user_ids))).all() if user_ids else []
    user_map = {u.id: u.name for u in users}

    result = []
    for doctor in doctors:
        result.append(DoctorResponse(
            id=doctor.id,
            nmid=doctor.nmid,
            degree=doctor.degree,
            specialty=doctor.specialty,
            verified=doctor.verified,
            user_id=doctor.user_id,
            name=user_map.get(doctor.user_id, "Unknown")
        ))

    return DoctorListResponse(doctors=result)


@router.get("/doctors/me", response_model=DoctorResponse)
async def get_my_doctor_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    _require_doctor_role(current_user)

    doctor = db.exec(select(Doctor).where(Doctor.user_id == current_user.id)).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor profile not found")

    return DoctorResponse(
        id=doctor.id,
        nmid=doctor.nmid,
        degree=doctor.degree,
        specialty=doctor.specialty,
        verified=doctor.verified,
        user_id=doctor.user_id,
        name=current_user.name
    )


class DoctorUpdate(BaseModel):
    nmid: Optional[str] = None
    degree: Optional[str] = None
    specialty: Optional[str] = None


@router.put("/doctors/me", response_model=DoctorResponse)
async def update_my_doctor_profile(
    doctor_data: DoctorUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    _require_doctor_role(current_user)

    doctor = db.exec(select(Doctor).where(Doctor.user_id == current_user.id)).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor profile not found")

    if doctor_data.nmid is not None:
        doctor.nmid = doctor_data.nmid
    if doctor_data.degree is not None:
        doctor.degree = doctor_data.degree
    if doctor_data.specialty is not None:
        doctor.specialty = doctor_data.specialty

    # A practitioner who edits the credentials they were verified against has
    # to be verified again. Only a real edit resets it: an empty PUT is a no-op
    # that must not silently unverify a working doctor. `verified` itself stays
    # operator-managed (ADD_DOCTOR_GUIDE.txt).
    if doctor_data.model_fields_set:
        doctor.verified = False

    db.add(doctor)
    db.commit()
    db.refresh(doctor)

    return DoctorResponse(
        id=doctor.id,
        nmid=doctor.nmid,
        degree=doctor.degree,
        specialty=doctor.specialty,
        verified=doctor.verified,
        user_id=doctor.user_id,
        name=current_user.name
    )


def _day_overlaps(
    db: Session, doctor_id: str, day_of_week: DayOfWeek,
    start_time: time, end_time: time, exclude_id: Optional[str] = None,
) -> bool:
    """True if the (day, start, end) window overlaps another availability row.

    Reused by create and update so the two paths cannot disagree. Rows on a
    different day never overlap, so the check is per-day.
    """
    existing = db.exec(
        select(DoctorAvailability)
        .where(
            (DoctorAvailability.doctor_id == doctor_id)
            & (DoctorAvailability.day_of_week == day_of_week)
            & (
                (DoctorAvailability.id != exclude_id)
                if exclude_id
                else True
            )
        )
    ).all()

    for ex in existing:
        if start_time < ex.end_time and end_time > ex.start_time:
            return True
    return False


def _reject_overlap(
    db: Session, doctor: Doctor, day_of_week: DayOfWeek,
    start_time: time, end_time: time, exclude_id: Optional[str] = None,
) -> None:
    if _day_overlaps(
        db, doctor.id, day_of_week, start_time, end_time, exclude_id
    ):
        raise HTTPException(
            status_code=400,
            detail=f"Overlapping availability exists for {day_of_week.value}",
        )


@router.post("/availability", response_model=AvailabilityResponse)
async def create_availability(
    avail_data: AvailabilityCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    _require_doctor_role(current_user)

    doctor = db.exec(select(Doctor).where(Doctor.user_id == current_user.id)).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor profile not found")

    _reject_overlap(
        db, doctor, avail_data.day_of_week,
        avail_data.start_time, avail_data.end_time,
    )

    availability = DoctorAvailability(
        doctor_id=doctor.id,
        day_of_week=avail_data.day_of_week,
        start_time=avail_data.start_time,
        end_time=avail_data.end_time,
        slot_duration_minutes=avail_data.slot_duration_minutes,
        is_available=avail_data.is_available
    )
    db.add(availability)
    db.commit()
    db.refresh(availability)

    return AvailabilityResponse(
        id=availability.id,
        day_of_week=availability.day_of_week.value,
        start_time=availability.start_time,
        end_time=availability.end_time,
        slot_duration_minutes=availability.slot_duration_minutes,
        is_available=availability.is_available
    )


@router.get("/availability", response_model=AvailabilityListResponse)
async def get_my_availability(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    _require_doctor_role(current_user)

    doctor = db.exec(select(Doctor).where(Doctor.user_id == current_user.id)).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor profile not found")

    availabilities = db.exec(
        select(DoctorAvailability)
        .where(DoctorAvailability.doctor_id == doctor.id)
    ).all()

    return AvailabilityListResponse(
        availability=[
            AvailabilityResponse(
                id=a.id,
                day_of_week=a.day_of_week.value,
                start_time=a.start_time,
                end_time=a.end_time,
                slot_duration_minutes=a.slot_duration_minutes,
                is_available=a.is_available
            )
            for a in availabilities
        ]
    )


@router.get("/availability/{doctor_id}", response_model=AvailabilityListResponse)
async def get_doctor_availability(
    doctor_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    doctor = db.get(Doctor, doctor_id)
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor not found")

    availabilities = db.exec(
        select(DoctorAvailability)
        .where(
            (DoctorAvailability.doctor_id == doctor_id) &
            (DoctorAvailability.is_available == True)
        )
    ).all()

    return AvailabilityListResponse(
        availability=[
            AvailabilityResponse(
                id=a.id,
                day_of_week=a.day_of_week.value,
                start_time=a.start_time,
                end_time=a.end_time,
                slot_duration_minutes=a.slot_duration_minutes,
                is_available=a.is_available
            )
            for a in availabilities
        ]
    )


@router.put("/availability/{avail_id}", response_model=AvailabilityResponse)
async def update_availability(
    avail_id: str,
    avail_data: AvailabilityUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    _require_doctor_role(current_user)

    doctor = db.exec(select(Doctor).where(Doctor.user_id == current_user.id)).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor profile not found")

    availability = db.get(DoctorAvailability, avail_id)
    if not availability or availability.doctor_id != doctor.id:
        raise HTTPException(status_code=404, detail="Availability not found")

    # Resolve the window the row will end up with, so the overlap check and the
    # end-after-start rule see the *merged* state — exactly what the create path
    # would have rejected before this row existed.
    new_day = avail_data.day_of_week if avail_data.day_of_week is not None else availability.day_of_week
    new_start = avail_data.start_time if avail_data.start_time is not None else availability.start_time
    new_end = avail_data.end_time if avail_data.end_time is not None else availability.end_time

    if new_end <= new_start:
        raise HTTPException(
            status_code=400,
            detail="end_time must be after start_time",
        )

    if availability.day_of_week != new_day or (
        availability.start_time != new_start or availability.end_time != new_end
    ):
        _reject_overlap(
            db, doctor, new_day, new_start, new_end,
            exclude_id=availability.id,
        )

    if avail_data.day_of_week is not None:
        availability.day_of_week = avail_data.day_of_week
    if avail_data.start_time is not None:
        availability.start_time = avail_data.start_time
    if avail_data.end_time is not None:
        availability.end_time = avail_data.end_time
    if avail_data.slot_duration_minutes is not None:
        availability.slot_duration_minutes = avail_data.slot_duration_minutes
    if avail_data.is_available is not None:
        availability.is_available = avail_data.is_available

    db.add(availability)
    db.commit()
    db.refresh(availability)

    return AvailabilityResponse(
        id=availability.id,
        day_of_week=availability.day_of_week.value,
        start_time=availability.start_time,
        end_time=availability.end_time,
        slot_duration_minutes=availability.slot_duration_minutes,
        is_available=availability.is_available
    )


@router.delete("/availability/{avail_id}")
async def delete_availability(
    avail_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    _require_doctor_role(current_user)

    doctor = db.exec(select(Doctor).where(Doctor.user_id == current_user.id)).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor profile not found")

    availability = db.get(DoctorAvailability, avail_id)
    if not availability or availability.doctor_id != doctor.id:
        raise HTTPException(status_code=404, detail="Availability not found")

    db.delete(availability)
    db.commit()
    return {"message": "Availability deleted"}