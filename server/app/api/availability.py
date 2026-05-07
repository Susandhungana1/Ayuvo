from datetime import time
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
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


class AvailabilityUpdate(BaseModel):
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

    result = []
    for doctor in doctors:
        doctor_user = db.exec(select(User).where(User.id == doctor.user_id)).first()
        result.append(DoctorResponse(
            id=doctor.id,
            nmid=doctor.nmid,
            degree=doctor.degree,
            specialty=doctor.specialty,
            verified=doctor.verified,
            user_id=doctor.user_id,
            name=doctor_user.name if doctor_user else "Unknown"
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

    # Check for overlapping availability
    existing = db.exec(
        select(DoctorAvailability)
        .where(
            (DoctorAvailability.doctor_id == doctor.id) &
            (DoctorAvailability.day_of_week == avail_data.day_of_week)
        )
    ).all()

    for ex in existing:
        if (avail_data.start_time < ex.end_time and avail_data.end_time > ex.start_time):
            raise HTTPException(
                status_code=400,
                detail=f"Overlapping availability exists for {avail_data.day_of_week.value}"
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