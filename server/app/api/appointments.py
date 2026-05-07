import httpx
from datetime import datetime, timezone, timedelta, time
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, field_validator
from sqlmodel import Session, select, and_
from app.api.auth import get_current_user
from app.core.config import get_session, settings
from app.models.models import User, Appointment, Doctor, DoctorAvailability, AppointmentStatus, DayOfWeek

router = APIRouter()


def get_day_of_week(dt: datetime) -> DayOfWeek:
    days = [DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.WEDNESDAY, DayOfWeek.THURSDAY, DayOfWeek.FRIDAY, DayOfWeek.SATURDAY, DayOfWeek.SUNDAY]
    return days[dt.weekday()]


class AppointmentCreate(BaseModel):
    title: str
    description: Optional[str] = None
    doctor_id: Optional[str] = None
    doctor_name: Optional[str] = None
    hospital: Optional[str] = None
    appointment_date: datetime
    duration_minutes: int = 30
    reason: Optional[str] = None

    @field_validator('appointment_date')
    @classmethod
    def appointment_must_be_future(cls, v: datetime) -> datetime:
        now = datetime.now(timezone.utc)
        if v.replace(tzinfo=timezone.utc) <= now:
            raise ValueError('Appointment date must be in the future')
        return v


class AppointmentResponse(BaseModel):
    id: str
    title: str
    description: Optional[str]
    doctor_id: Optional[str]
    doctor_name: Optional[str]
    hospital: Optional[str]
    appointment_date: datetime
    duration_minutes: int
    status: str
    reason: Optional[str]
    reminder_sent: bool


class AppointmentListResponse(BaseModel):
    appointments: List[AppointmentResponse]


class AvailableSlot(BaseModel):
    start_time: datetime
    end_time: datetime


class AvailableSlotsResponse(BaseModel):
    doctor_id: str
    doctor_name: str
    available_slots: List[AvailableSlot]


async def send_n8n_webhook(appointment: Appointment, user_email: str):
    if not settings.n8n_webhook_url:
        return
    try:
        async with httpx.AsyncClient() as client:
            await client.post(
                settings.n8n_webhook_url,
                json={
                    "type": "appointment_reminder",
                    "title": appointment.title,
                    "date": appointment.appointment_date.isoformat(),
                    "email": user_email
                }
            )
    except Exception:
        pass


def get_available_slots_for_doctor(db: Session, doctor_id: str, date: datetime, duration_minutes: int = 30) -> List[AvailableSlot]:
    day_of_week = get_day_of_week(date)
    availabilities = db.exec(
        select(DoctorAvailability).where(
            and_(
                DoctorAvailability.doctor_id == doctor_id,
                DoctorAvailability.day_of_week == day_of_week,
                DoctorAvailability.is_available == True
            )
        )
    ).all()

    if not availabilities:
        return []

    start_of_day = date.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = start_of_day + timedelta(days=1)

    existing_appointments = db.exec(
        select(Appointment).where(
            and_(
                Appointment.doctor_id == doctor_id,
                Appointment.appointment_date >= start_of_day,
                Appointment.appointment_date < end_of_day
            )
        )
    ).all()

    booked_slots = []
    for appt in existing_appointments:
        if appt.status in [AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED]:
            appt_start = appt.appointment_date
            appt_end = appt_start + timedelta(minutes=appt.duration_minutes)
            booked_slots.append((appt_start, appt_end))

    available_slots = []
    for availability in availabilities:
        slot_start = datetime.combine(date.date(), availability.start_time)
        slot_end = datetime.combine(date.date(), availability.end_time)

        current_time = slot_start
        while current_time + timedelta(minutes=duration_minutes) <= slot_end:
            slot_end_time = current_time + timedelta(minutes=duration_minutes)

            is_available = True
            for booked_start, booked_end in booked_slots:
                if current_time < booked_end and slot_end_time > booked_start:
                    is_available = False
                    break

            if is_available:
                available_slots.append(AvailableSlot(start_time=current_time, end_time=slot_end_time))

            slot_duration = availability.slot_duration_minutes or duration_minutes
            current_time += timedelta(minutes=slot_duration)

    return available_slots


def is_slot_available(db: Session, doctor_id: str, appointment_date: datetime, duration_minutes: int) -> bool:
    if appointment_date.tzinfo is None:
        appointment_date = appointment_date.replace(tzinfo=timezone.utc)
    
    day_of_week = get_day_of_week(appointment_date)

    availabilities = db.exec(
        select(DoctorAvailability).where(
            and_(
                DoctorAvailability.doctor_id == doctor_id,
                DoctorAvailability.day_of_week == day_of_week,
                DoctorAvailability.is_available == True
            )
        )
    ).all()

    if not availabilities:
        return False

    appt_time = appointment_date.time()
    appt_end_dt = appointment_date + timedelta(minutes=duration_minutes)
    appt_end_time = appt_end_dt.time()

    in_window = False
    for availability in availabilities:
        if availability.start_time <= appt_time and appt_end_time <= availability.end_time:
            in_window = True
            break

    if not in_window:
        return False

    appt_end = appointment_date + timedelta(minutes=duration_minutes)

    overlapping = db.exec(
        select(Appointment).where(
            and_(
                Appointment.doctor_id == doctor_id,
                Appointment.appointment_date < appt_end.replace(tzinfo=None)
            )
        )
    ).first()

    if overlapping and overlapping.status in [AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED]:
        appt_start = overlapping.appointment_date
        if appt_start.tzinfo is None:
            appt_start = appt_start.replace(tzinfo=timezone.utc)
        appt_dur = overlapping.duration_minutes
        if appt_start + timedelta(minutes=appt_dur) > appointment_date:
            return False

    return True


@router.post("", response_model=AppointmentResponse)
async def create_appointment(
    appt_data: AppointmentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    if appt_data.doctor_id:
        doctor = db.get(Doctor, appt_data.doctor_id)
        if not doctor:
            raise HTTPException(status_code=404, detail="Doctor not found")

        if not is_slot_available(db, appt_data.doctor_id, appt_data.appointment_date, appt_data.duration_minutes):
            raise HTTPException(status_code=400, detail="The requested time slot is not available. Please check the doctor's available slots.")

    status = AppointmentStatus.CONFIRMED if appt_data.doctor_id else AppointmentStatus.PENDING

    appointment = Appointment(
        user_id=current_user.id,
        title=appt_data.title,
        description=appt_data.description,
        doctor_id=appt_data.doctor_id,
        doctor_name=appt_data.doctor_name,
        hospital=appt_data.hospital,
        appointment_date=appt_data.appointment_date,
        duration_minutes=appt_data.duration_minutes,
        reason=appt_data.reason,
        status=status
    )
    db.add(appointment)
    db.commit()
    db.refresh(appointment)

    return AppointmentResponse(
        id=appointment.id,
        title=appointment.title,
        description=appointment.description,
        doctor_id=appointment.doctor_id,
        doctor_name=appointment.doctor_name,
        hospital=appointment.hospital,
        appointment_date=appointment.appointment_date,
        duration_minutes=appointment.duration_minutes,
        status=appointment.status.value if isinstance(appointment.status, AppointmentStatus) else appointment.status,
        reason=appointment.reason,
        reminder_sent=appointment.reminder_sent
    )


@router.get("", response_model=AppointmentListResponse)
async def list_appointments(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    appointments = db.exec(
        select(Appointment)
        .where(Appointment.user_id == current_user.id)
        .order_by(Appointment.appointment_date.asc())
    ).all()

    return AppointmentListResponse(
        appointments=[
            AppointmentResponse(
                id=a.id,
                title=a.title,
                description=a.description,
                doctor_id=a.doctor_id,
                doctor_name=a.doctor_name,
                hospital=a.hospital,
                appointment_date=a.appointment_date,
                duration_minutes=a.duration_minutes,
                status=a.status.value if isinstance(a.status, AppointmentStatus) else a.status,
                reason=a.reason,
                reminder_sent=a.reminder_sent
            )
            for a in appointments
        ]
    )


@router.get("/available-slots/{doctor_id}", response_model=AvailableSlotsResponse)
async def get_available_slots(
    doctor_id: str,
    date: datetime,
    duration_minutes: int = 30,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    doctor = db.get(Doctor, doctor_id)
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor not found")

    doctor_user = db.get(User, doctor.user_id)
    doctor_name = doctor_user.name if doctor_user else "Unknown Doctor"

    available_slots = get_available_slots_for_doctor(db, doctor_id, date, duration_minutes)

    return AvailableSlotsResponse(
        doctor_id=doctor_id,
        doctor_name=doctor_name,
        available_slots=available_slots
    )


@router.put("/{appt_id}", response_model=AppointmentResponse)
async def update_appointment(
    appt_id: str,
    appt_data: AppointmentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    appointment = db.get(Appointment, appt_id)
    if not appointment or appointment.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Appointment not found")

    if appt_data.doctor_id:
        doctor = db.get(Doctor, appt_data.doctor_id)
        if not doctor:
            raise HTTPException(status_code=404, detail="Doctor not found")

        if not is_slot_available(db, appt_data.doctor_id, appt_data.appointment_date, appt_data.duration_minutes):
            raise HTTPException(status_code=400, detail="The requested time slot is not available.")

    appointment.title = appt_data.title
    appointment.description = appt_data.description
    appointment.doctor_id = appt_data.doctor_id
    appointment.doctor_name = appt_data.doctor_name
    appointment.hospital = appt_data.hospital
    appointment.appointment_date = appt_data.appointment_date
    appointment.duration_minutes = appt_data.duration_minutes
    appointment.reason = appt_data.reason
    appointment.updated_at = datetime.utcnow()

    db.add(appointment)
    db.commit()
    db.refresh(appointment)

    return AppointmentResponse(
        id=appointment.id,
        title=appointment.title,
        description=appointment.description,
        doctor_id=appointment.doctor_id,
        doctor_name=appointment.doctor_name,
        hospital=appointment.hospital,
        appointment_date=appointment.appointment_date,
        duration_minutes=appointment.duration_minutes,
        status=appointment.status.value if isinstance(appointment.status, AppointmentStatus) else appointment.status,
        reason=appointment.reason,
        reminder_sent=appointment.reminder_sent
    )


@router.patch("/{appt_id}/status", response_model=AppointmentResponse)
async def update_appointment_status(
    appt_id: str,
    status: AppointmentStatus,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    appointment = db.get(Appointment, appt_id)
    if not appointment or appointment.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Appointment not found")

    appointment.status = status
    appointment.updated_at = datetime.utcnow()

    db.add(appointment)
    db.commit()
    db.refresh(appointment)

    return AppointmentResponse(
        id=appointment.id,
        title=appointment.title,
        description=appointment.description,
        doctor_id=appointment.doctor_id,
        doctor_name=appointment.doctor_name,
        hospital=appointment.hospital,
        appointment_date=appointment.appointment_date,
        duration_minutes=appointment.duration_minutes,
        status=appointment.status.value if isinstance(appointment.status, AppointmentStatus) else appointment.status,
        reason=appointment.reason,
        reminder_sent=appointment.reminder_sent
    )


@router.delete("/{appt_id}")
async def delete_appointment(
    appt_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    appointment = db.get(Appointment, appt_id)
    if not appointment or appointment.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Appointment not found")

    db.delete(appointment)
    db.commit()
    return {"message": "Appointment deleted"}


@router.get("/doctor/my-appointments", response_model=AppointmentListResponse)
async def list_doctor_appointments(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    if current_user.role not in ["DOCTOR", "ADMIN"]:
        raise HTTPException(status_code=403, detail="Only doctors can access this resource")
    
    doctor = db.exec(select(Doctor).where(Doctor.user_id == current_user.id)).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor profile not found")
    
    appointments = db.exec(
        select(Appointment)
        .where(Appointment.doctor_id == doctor.id)
        .order_by(Appointment.appointment_date.asc())
    ).all()
    
    return AppointmentListResponse(
        appointments=[
            AppointmentResponse(
                id=a.id,
                title=a.title,
                description=a.description,
                doctor_id=a.doctor_id,
                doctor_name=a.doctor_name,
                hospital=a.hospital,
                appointment_date=a.appointment_date,
                duration_minutes=a.duration_minutes,
                status=a.status.value if isinstance(a.status, AppointmentStatus) else a.status,
                reason=a.reason,
                reminder_sent=a.reminder_sent
            )
            for a in appointments
        ]
    )