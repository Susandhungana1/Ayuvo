"""Schema migration for Phase 0 and caretaker columns/tables on an EXISTING database.

The app creates tables with `SQLModel.metadata.create_all`, which creates
*missing* tables but never alters existing ones. So a database that predates
Phase 0 will be missing the new columns and the audit_logs table. On a brand-new
(empty) database you do NOT need this — first startup creates everything.

Run this once against a pre-Phase-0 database, before switching production
traffic and before running `migrate_blobs_to_storage`.

It is idempotent: it adds columns only if absent and creates audit_logs only if
missing, so running it twice is harmless.

    Adds:  users.totp_secret, users.totp_enabled
           users.timezone                    (mobile: the user's own IANA zone)
           medical_reports.storage_key
           medical_reports.ocr_status        (background OCR state machine)
           medical_reports.lab_overrides     (user corrections to OCR'd values)
           medical_files.storage_key, medical_files.content_type
           medicines.deleted_at              (caretaker: soft delete)
            share_links.pin_hash              (PIN-protected whole-record shares)
            share_links.failed_pin_attempts   (per-link PIN lockout)
    Drops: medical_reports.result_summary, medical_reports.ai_report_text
           (AI features removed; the AI text is deleted with them)
           emergency_contacts.relationship, emergency_contacts.email
           (emergency ID simplified: only name + phone are needed)
    Relaxes (so legacy blobs can be moved out): medical_reports.file_content and
           medical_files.content become NULLable.
    Creates: audit_logs table, and the caretaker tables — care_invites,
           care_links, medicine_audit, reminder_deliveries (via SQLModel
           metadata, which also builds their indexes and constraints).

Usage:
    cd server
    python -m scripts.migrate_schema           # apply
    python -m scripts.migrate_schema --dry-run  # print what it would do
"""

import sys

from sqlalchemy import text
from sqlmodel import SQLModel

from app.core.config import engine
# Import models so SQLModel.metadata knows about audit_logs et al.
from app.models import models  # noqa: F401


# (table, column, "ADD COLUMN" type clause). IF NOT EXISTS keeps it idempotent.
_ADD_COLUMNS = [
    ("users", "totp_secret", "VARCHAR"),
    ("users", "totp_enabled", "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("users", "timezone", "VARCHAR"),
    ("medical_reports", "storage_key", "VARCHAR"),
    ("medical_reports", "ocr_status", "VARCHAR"),
    ("medical_reports", "lab_overrides", "JSON"),
    ("medical_files", "storage_key", "VARCHAR"),
    ("medical_files", "content_type", "VARCHAR"),
    # Caretaker: medicine deletes became soft, so the patient can restore what a
    # caretaker removed. Every read filters deleted_at IS NULL; existing rows
    # default to NULL and are therefore untouched.
    ("medicines", "deleted_at", "TIMESTAMP"),
    # PIN guarding whole-record (QR) shares.
    ("share_links", "pin_hash", "VARCHAR"),
    # Per-link wrong-PIN counter so the lockout survives the in-memory state.
    ("share_links", "failed_pin_attempts", "INTEGER NOT NULL DEFAULT 0"),
]

# Indexes that belong to columns added above. SQLModel builds these for a fresh
# table, but ADD COLUMN on an existing one does not.
_ADD_INDEXES = [
    ("ix_medicines_deleted_at", "medicines", "deleted_at"),
]

# AI columns removed with the feature: the AI-generated text is deleted, the
# OCR extracted_text column stays (the offline lab parser reads it).
# Emergency ID simplified: relationship and email never used in the UI.
_DROP_COLUMNS = [
    ("medical_reports", "result_summary"),
    ("medical_reports", "ai_report_text"),
    ("emergency_contacts", "relationship"),
    ("emergency_contacts", "email"),
]

# Legacy blob columns that must become nullable so the backfill can NULL them.
_DROP_NOT_NULL = [
    ("medical_reports", "file_content"),
    ("medical_files", "content"),
]


def migrate(dry_run: bool = False) -> None:
    dialect = engine.dialect.name
    if dialect != "postgresql":
        print(
            f"Refusing to run: this migration targets PostgreSQL, but the "
            f"configured database is '{dialect}'. Point DATABASE_URL at your "
            f"production Postgres and re-run."
        )
        sys.exit(1)

    stmts: list[str] = []
    for table, col, type_clause in _ADD_COLUMNS:
        stmts.append(
            f'ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {col} {type_clause};'
        )
    for table, col in _DROP_COLUMNS:
        stmts.append(f'ALTER TABLE {table} DROP COLUMN IF EXISTS {col};')
    for table, col in _DROP_NOT_NULL:
        stmts.append(f'ALTER TABLE {table} ALTER COLUMN {col} DROP NOT NULL;')
    for name, table, col in _ADD_INDEXES:
        stmts.append(f'CREATE INDEX IF NOT EXISTS {name} ON {table} ({col});')

    if dry_run:
        print(f"Target: {engine.url}")
        print("Would create any missing tables (audit_logs, care_*, "
              "medicine_audit, reminder_deliveries), then run:")
        for s in stmts:
            print(f"  {s}")
        return

    # 1) Create any missing tables — does not touch existing tables.
    SQLModel.metadata.create_all(engine)

    # 2) Add/relax columns on existing tables.
    with engine.begin() as conn:
        for s in stmts:
            conn.execute(text(s))

    print(
        "Schema migration applied: added Phase 0 + caretaker columns, relaxed "
        "legacy blob columns to NULLable, and ensured audit_logs and the "
        "caretaker tables exist.\n"
        "Next: python -m scripts.migrate_blobs_to_storage"
    )


if __name__ == "__main__":
    migrate(dry_run="--dry-run" in sys.argv)