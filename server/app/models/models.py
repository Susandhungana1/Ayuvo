from datetime import datetime, time
from enum import Enum
from sqlmodel import SQLModel, Field, Relationship
from sqlalchemy import LargeBinary
from typing import Optional
import uuid


class Role(str, Enum):
    PATIENT = "PATIENT"
    DOCTOR = "DOCTOR"
    ADMIN = "ADMIN"


class FileType(str, Enum):
    DOCTOR_TICKET = "DOCTOR_TICKET"
    MEDICINES = "MEDICINES"
    MEDICAL_REPORTS = "MEDICAL_REPORTS"
    OTHER = "OTHER"


class MedicalReportType(str, Enum):
    BLOOD_TEST = "BLOOD_TEST"
    URINE_TEST = "URINE_TEST"
    STOOL_TEST = "STOOL_TEST"
    XRAY = "XRAY"
    MRI = "MRI"
    CT_SCAN = "CT_SCAN"
    ECG = "ECG"
    ULTRASOUND = "ULTRASOUND"
    LAB_REPORT = "LAB_REPORT"
    OTHERS = "OTHERS"


class AppointmentStatus(str, Enum):
    PENDING = "PENDING"
    CONFIRMED = "CONFIRMED"
    CANCELLED = "CANCELLED"
    COMPLETED = "COMPLETED"


class DayOfWeek(str, Enum):
    MONDAY = "MONDAY"
    TUESDAY = "TUESDAY"
    WEDNESDAY = "WEDNESDAY"
    THURSDAY = "THURSDAY"
    FRIDAY = "FRIDAY"
    SATURDAY = "SATURDAY"
    SUNDAY = "SUNDAY"


class IDCounter(SQLModel, table=True):
    """Counter table for generating sequential user IDs"""
    __tablename__ = "id_counter"

    id: int = Field(default=None, primary_key=True)
    last_number: int = Field(default=0)


# Import ID generator here to avoid circular imports at module level
def _get_user_id() -> str:
    from app.core.id_generator import generate_user_id
    return generate_user_id()


class User(SQLModel, table=True):
    __tablename__ = "users"

    id: str = Field(default_factory=_get_user_id, primary_key=True)
    name: str
    email: str = Field(unique=True, index=True)
    password: str
    role: str = Field(default="PATIENT")

    address: Optional[str] = None
    city: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

    blood_type: Optional[str] = None
    allergies: Optional[str] = None
    medical_conditions: Optional[str] = None

    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class Doctor(SQLModel, table=True):
    __tablename__ = "doctors"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    nmid: str
    degree: str
    specialty: Optional[str] = None
    verified: bool = Field(default=False)

    user_id: str = Field(foreign_key="users.id", unique=True)


class DoctorAvailability(SQLModel, table=True):
    """Doctor's available time slots for appointments"""
    __tablename__ = "doctor_availability"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    doctor_id: str = Field(foreign_key="doctors.id", index=True)

    day_of_week: DayOfWeek
    start_time: time
    end_time: time
    slot_duration_minutes: int = Field(default=30)
    is_available: bool = Field(default=True)

    # Optional: specific date override (for holidays, special schedules)
    specific_date: Optional[datetime] = None


class MedicalDocument(SQLModel, table=True):
    __tablename__ = "medical_documents"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id", index=True)

    hospital: str
    location: Optional[str] = None
    doctor_name: Optional[str] = None
    department: Optional[str] = None
    description: Optional[str] = None

    checkup_date: datetime = Field(default_factory=datetime.utcnow)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    deleted_at: Optional[datetime] = None


class Medicine(SQLModel, table=True):
    __tablename__ = "medicines"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id", index=True)
    name: str
    dosage: str
    frequency: str
    start_date: str
    end_date: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


class MedicalFile(SQLModel, table=True):
    __tablename__ = "medical_files"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    name: str
    file_type: FileType
    content: bytes = Field(default=None, sa_type=LargeBinary())

    document_id: str = Field(foreign_key="medical_documents.id")
    uploaded_at: datetime = Field(default_factory=datetime.utcnow)


class MedicalReport(SQLModel, table=True):
    __tablename__ = "medical_reports"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id", index=True)
    document_id: Optional[str] = Field(default=None, foreign_key="medical_documents.id")

    report_type: MedicalReportType
    report_date: Optional[datetime] = None

    file_name: str
    file_content: bytes = Field(default=None, sa_type=LargeBinary())
    file_content_type: Optional[str] = None
    thumbnail: Optional[str] = None
    notes: Optional[str] = None

    result_summary: Optional[str] = None
    extracted_text: Optional[str] = None
    ai_report_text: Optional[str] = None

    created_at: datetime = Field(default_factory=datetime.utcnow)


class Appointment(SQLModel, table=True):
    __tablename__ = "appointments"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id", index=True)

    # Link to doctor (optional - can also use doctor_name for external doctors)
    doctor_id: Optional[str] = Field(default=None, foreign_key="doctors.id")
    doctor_name: Optional[str] = None
    hospital: Optional[str] = None

    title: str
    description: Optional[str] = None

    # Appointment details
    appointment_date: datetime
    duration_minutes: int = Field(default=30)
    status: AppointmentStatus = Field(default=AppointmentStatus.PENDING)

    # Reason for visit
    reason: Optional[str] = None

    reminder_sent: bool = Field(default=False)

    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class ShareLink(SQLModel, table=True):
    __tablename__ = "share_links"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    token: str = Field(unique=True, index=True)

    report_id: Optional[str] = Field(default=None)
    user_id: str = Field(foreign_key="users.id")
    all_reports: bool = Field(default=False)

    expires_at: datetime
    created_at: datetime = Field(default_factory=datetime.utcnow)


class VitalSign(SQLModel, table=True):
    __tablename__ = "vital_signs"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id", index=True)

    blood_pressure_systolic: Optional[int] = None
    blood_pressure_diastolic: Optional[int] = None
    heart_rate: Optional[int] = None
    weight: Optional[float] = None
    blood_sugar: Optional[float] = None
    temperature: Optional[float] = None
    oxygen_saturation: Optional[int] = None

    notes: Optional[str] = None
    measured_at: datetime = Field(default_factory=datetime.utcnow)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class EmergencyContact(SQLModel, table=True):
    __tablename__ = "emergency_contacts"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id", index=True)

    name: str
    relationship: str
    phone: str
    email: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
