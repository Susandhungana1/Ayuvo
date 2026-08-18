from datetime import datetime, time
from enum import Enum
from sqlmodel import SQLModel, Field, Relationship
from sqlalchemy import (
    LargeBinary, JSON, Index, UniqueConstraint, CheckConstraint, text,
    Column, ForeignKey, String,
)
from typing import Any, Optional
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

    # The user's own IANA timezone (e.g. "Asia/Kathmandu"), set by the mobile app
    # at sign-in. Weak location data: optional, unset by default, never logged.
    # When set, dose-time lookup prefers it over the push-subscription inference.
    timezone: Optional[str] = None

    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class PasswordResetToken(SQLModel, table=True):
    """Single-use password reset token. Only the SHA-256 hash is stored, so a
    DB leak doesn't hand out working reset links."""
    __tablename__ = "password_reset_tokens"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id", index=True)
    token_hash: str = Field(unique=True, index=True)
    expires_at: datetime
    used: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class RefreshToken(SQLModel, table=True):
    """Long-lived session token, stored hashed so a DB leak doesn't hand out
    working sessions. Access tokens are stateless JWTs (short expiry); this
    row is the state that makes revocation and rotation possible.

    Rotation: every successful refresh revokes the presented token and writes a
    successor. Presenting an already-revoked token is the signature of a stolen
    token replay, so that revokes the whole chain (family) for the user.
    """
    __tablename__ = "refresh_tokens"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id", index=True)
    token_hash: str = Field(unique=True, index=True)
    expires_at: datetime
    revoked_at: Optional[datetime] = None
    replaced_by: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


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
    # Soft delete: a caretaker's removal must be reversible by the patient, so
    # rows are retired rather than dropped. Every read filters deleted_at IS NULL.
    deleted_at: Optional[datetime] = Field(default=None, index=True)


class MedicineIntakeLog(SQLModel, table=True):
    """Adherence record: one row each time a dose is acted on (taken/snoozed)."""

    __tablename__ = "medicine_intake_logs"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id", index=True)
    medicine_id: str = Field(foreign_key="medicines.id", index=True)
    # The scheduled clock time this dose was for, e.g. "08:00".
    scheduled_time: str
    # "taken" | "snoozed" | "skipped"
    status: str = "taken"
    recorded_at: datetime = Field(default_factory=datetime.utcnow)


class PushSubscription(SQLModel, table=True):
    """A browser/device Web Push subscription used to deliver medicine reminders
    when the app is closed. One user may have several (phone, laptop, …)."""

    __tablename__ = "push_subscriptions"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id", index=True)
    endpoint: str = Field(unique=True)
    p256dh: str
    auth: str
    # IANA tz (e.g. "Asia/Kathmandu") so the scheduler fires at the user's local
    # clock time, not the server's UTC.
    timezone: str = "UTC"
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

    # OCR-extracted text, kept for the offline lab-value parser (/lab-analysis,
    # /trends). The AI-generated summary/formal-report columns were removed.
    extracted_text: Optional[str] = None

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

    # 6-digit PIN guarding whole-record (QR) shares. Single-report shares stay
    # PIN-free: they carry one consented report, not the whole health record.
    # Stored hashed so a leaked DB dump does not hand out working PINs.
    pin_hash: Optional[str] = Field(default=None)

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


# --- Caretaker ---------------------------------------------------------------
#
# A caretaker is an ordinary user account, not a role: any user may be a
# patient, a caretaker, or both. A patient issues a short-lived code; a
# caretaker redeems it, producing a CareLink that grants exactly two things —
# medicine reminders for that patient, and read/write on that patient's
# medicines. Nothing else (vitals, documents, reports, AI) is reachable.
#
# Note these use str primary keys and str foreign keys, matching the rest of the
# schema: users.id is "#hos001", not a UUID.


def _user_fk(*, cascade: bool, index: bool = False, nullable: bool = False) -> Column:
    """A foreign key to users.id.

    Spelled out as an explicit Column because this sqlmodel version's Field()
    has no `ondelete`, and these tables need it: a care link or a queued
    delivery addressed to a deleted account is meaningless, so it goes with the
    account. Actor/revoker columns deliberately do NOT cascade — losing who did
    what would gut the audit trail.
    """
    return Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE" if cascade else None),
        index=index,
        nullable=nullable,
    )


class CareInvite(SQLModel, table=True):
    """A pending invite code issued by a patient.

    Only the SHA-256 hash of the code is stored, so a database leak can't be
    replayed into account access — same reasoning as PasswordResetToken.
    """
    __tablename__ = "care_invites"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    patient_id: str = Field(sa_column=_user_fk(cascade=True, index=True))
    # Only the hash. Deliberately no plaintext prefix column: storing part of
    # the code beside its own hash would cut an offline search of the 8-char
    # space from ~10^12 to ~10^6, and nothing needs it — the UI shows the full
    # code once, at generation time, from memory.
    code_hash: str = Field(index=True)

    expires_at: datetime
    used_at: Optional[datetime] = None
    used_by: Optional[str] = Field(
        default=None, sa_column=_user_fk(cascade=False, nullable=True)
    )
    created_at: datetime = Field(default_factory=datetime.utcnow)


class CareLink(SQLModel, table=True):
    """An accepted caretaker relationship.

    The partial unique index allows exactly one *active* link per ordered
    (patient, caretaker) pair while leaving any number of revoked historical
    rows in place. Because the pair is ordered, mutual caretaking (A cares for
    B and B cares for A) is two distinct rows and works naturally.
    """
    __tablename__ = "care_links"
    __table_args__ = (
        Index(
            "care_links_unique_active",
            "patient_id",
            "caretaker_id",
            unique=True,
            postgresql_where=text("status = 'active'"),
            sqlite_where=text("status = 'active'"),
        ),
        CheckConstraint("patient_id <> caretaker_id", name="care_links_no_self"),
    )

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    patient_id: str = Field(sa_column=_user_fk(cascade=True, index=True))
    caretaker_id: str = Field(sa_column=_user_fk(cascade=True, index=True))

    status: str = Field(default="active")          # active | revoked
    # The caretaker may mute one client without severing the link.
    notify: bool = Field(default=True)

    created_at: datetime = Field(default_factory=datetime.utcnow)
    revoked_at: Optional[datetime] = None
    revoked_by: Optional[str] = Field(
        default=None, sa_column=_user_fk(cascade=False, nullable=True)
    )


class MedicineAudit(SQLModel, table=True):
    """Who changed which medicine, so a patient can see caretaker activity.

    Distinct from the generic audit_logs table: that one records *access* as
    short free text, whereas this needs the full before/after row so the
    patient can restore a medicine a caretaker deleted.
    """
    __tablename__ = "medicine_audit"

    id: Optional[int] = Field(default=None, primary_key=True)
    patient_id: str = Field(sa_column=_user_fk(cascade=True, index=True))
    actor_id: str = Field(sa_column=_user_fk(cascade=False, index=True))
    medicine_id: Optional[str] = None

    action: str                                     # create | update | delete | restore
    # JSON (not JSONB): the test suite runs on SQLite, which has no JSONB.
    before: Optional[dict[str, Any]] = Field(default=None, sa_type=JSON)
    after: Optional[dict[str, Any]] = Field(default=None, sa_type=JSON)

    created_at: datetime = Field(default_factory=datetime.utcnow, index=True)


class ReminderDelivery(SQLModel, table=True):
    """Ledger of reminder pushes, one row per (dose slot, recipient).

    The unique constraint is the point of the table: it makes fan-out
    idempotent across scheduler retries and process restarts (the old in-memory
    dedupe lost its state on reboot), and it stops a caretaker who links
    mid-day from being backfilled with dose slots that already passed.
    """
    __tablename__ = "reminder_deliveries"
    __table_args__ = (
        UniqueConstraint(
            "medicine_id", "recipient_id", "scheduled_for", "channel",
            name="reminder_deliveries_dedupe",
        ),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    medicine_id: str = Field(index=True)
    patient_id: str = Field(index=True)
    recipient_id: str = Field(sa_column=_user_fk(cascade=True, index=True))

    # The exact dose slot in the patient's local timezone, not the send time.
    scheduled_for: datetime
    channel: str = Field(default="webpush")
    status: str                                     # sent | failed | skipped
    error: Optional[str] = None

    created_at: datetime = Field(default_factory=datetime.utcnow)


# --- Claimed shares ----------------------------------------------------------
#
# A share link is a bearer token: whoever holds it reads the records until it
# expires, and the server never learns who looked. A *claim* inverts that — a
# signed-in recipient asks to keep what they were shown, and in doing so gives
# up their anonymity. That is the point of the feature as much as the
# persistence is: the owner finally gets to see who is holding their reports.
#
# Deliberately a snapshot of report IDs, never a copy of the rows:
#   - the recipient must not see reports uploaded *after* the claim, because
#     the consent was for what was on screen at that moment; and
#   - the bytes stay in exactly one place, so an owner deleting a report
#     removes it from every recipient's view too.
#
# Lives down here, below the caretaker block, only because it needs _user_fk.


class ClaimedShare(SQLModel, table=True):
    """A share a signed-in recipient kept, outliving the link's expiry."""

    __tablename__ = "claimed_shares"
    __table_args__ = (
        # One active claim per (recipient, token), so pressing "Save" twice is
        # idempotent instead of stacking duplicates. Scoped to active rows —
        # matching care_links — so a revoked claim doesn't permanently bar
        # re-claiming a link that is still valid.
        Index(
            "claimed_shares_unique_active",
            "recipient_id",
            "token",
            unique=True,
            postgresql_where=text("status = 'active'"),
            sqlite_where=text("status = 'active'"),
        ),
        CheckConstraint("recipient_id <> owner_id", name="claimed_shares_no_self"),
    )

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    # The token that was claimed. Kept so a second click on the same link is
    # recognised as the same claim; never re-validated on read, because by then
    # the link has usually expired and that is exactly what the claim survives.
    token: str = Field(index=True)

    recipient_id: str = Field(sa_column=_user_fk(cascade=True, index=True))
    owner_id: str = Field(sa_column=_user_fk(cascade=True, index=True))

    kind: str                                       # report | all
    # The reports visible at claim time — frozen. JSON (not JSONB): the test
    # suite runs on SQLite, which has no JSONB.
    report_ids: list[str] = Field(default_factory=list, sa_type=JSON)
    # The owner's name as it read at claim time, so the recipient's list can
    # say who sent it without joining users on every render.
    owner_name: str

    status: str = Field(default="active")           # active | revoked
    claimed_at: datetime = Field(default_factory=datetime.utcnow, index=True)
    revoked_at: Optional[datetime] = None
    revoked_by: Optional[str] = Field(
        default=None, sa_column=_user_fk(cascade=False, nullable=True)
    )
