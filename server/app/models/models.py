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

    # Two-factor auth (TOTP). Secret is base32; only set once the user enables 2FA.
    totp_secret: Optional[str] = None
    totp_enabled: bool = Field(default=False)

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
    taking_times: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


class MedicalFile(SQLModel, table=True):
    __tablename__ = "medical_files"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    name: str
    file_type: FileType

    # New: object-storage key (Phase 0). Bytes live in storage, not Postgres.
    storage_key: Optional[str] = None
    content_type: Optional[str] = None

    # Legacy: inline blob. Kept nullable so pre-migration rows still read; new
    # uploads leave this NULL and use storage_key instead.
    content: Optional[bytes] = Field(default=None, sa_type=LargeBinary())

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
    # New: object-storage key (Phase 0). Legacy file_content kept nullable for
    # pre-migration rows; new uploads use storage_key.
    storage_key: Optional[str] = None
    file_content: Optional[bytes] = Field(default=None, sa_type=LargeBinary())
    file_content_type: Optional[str] = None
    thumbnail: Optional[str] = None
    notes: Optional[str] = None
    hospital: Optional[str] = None
    doctor_name: Optional[str] = None

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


class Dependent(SQLModel, table=True):
    """A family member (child, elderly parent, etc.) whose basic medical
    profile is managed by a guardian account."""
    __tablename__ = "dependents"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    # The guardian account that owns/manages this dependent's records.
    guardian_id: str = Field(foreign_key="users.id", index=True)

    name: str
    relationship: str  # e.g. Child, Parent, Spouse
    date_of_birth: Optional[str] = None
    blood_type: Optional[str] = None
    allergies: Optional[str] = None
    medical_conditions: Optional[str] = None
    notes: Optional[str] = None

    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class AuditLog(SQLModel, table=True):
    """Append-only record of sensitive access events (who / when / what / IP).

    Required for privacy compliance and hospital trust: every read of a report,
    every share-link view, and every emergency-ID lookup is logged here. Rows
    are only ever inserted, never updated or deleted by application code.
    """
    __tablename__ = "audit_logs"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)

    # The actor. NULL for anonymous/public access (e.g. a share-link viewer).
    actor_id: Optional[str] = Field(default=None, index=True)
    # Whose data was touched (the data subject).
    subject_id: Optional[str] = Field(default=None, index=True)

    action: str = Field(index=True)          # e.g. "report.read", "share.view"
    resource_type: Optional[str] = None      # e.g. "MedicalReport"
    resource_id: Optional[str] = None

    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    detail: Optional[str] = None             # short free-text / token, no PII blobs

    created_at: datetime = Field(default_factory=datetime.utcnow, index=True)
