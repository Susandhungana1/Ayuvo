"""Schema migration for Phase 0 columns/tables on an EXISTING database.

The app creates tables with `SQLModel.metadata.create_all`, which creates
*missing* tables but never alters existing ones. So a database that predates
Phase 0 will be missing the new columns and the audit_logs table. On a brand-new
(empty) database you do NOT need this — first startup creates everything.

Run this once against a pre-Phase-0 database, before switching production
traffic and before running `migrate_blobs_to_storage`.

It is idempotent: it adds columns only if absent and creates audit_logs only if
missing, so running it twice is harmless.

    Adds:  users.totp_secret, users.totp_enabled
           medical_reports.storage_key
           medical_files.storage_key, medical_files.content_type
    Relaxes (so legacy blobs can be moved out): medical_reports.file_content and
           medical_files.content become NULLable.
    Creates: audit_logs table (via SQLModel metadata).

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
    ("medical_reports", "storage_key", "VARCHAR"),
    ("medical_files", "storage_key", "VARCHAR"),
    ("medical_files", "content_type", "VARCHAR"),
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
    for table, col in _DROP_NOT_NULL:
        stmts.append(f'ALTER TABLE {table} ALTER COLUMN {col} DROP NOT NULL;')

    if dry_run:
        print("Would create table audit_logs if missing, then run:")
        for s in stmts:
            print(f"  {s}")
        return

    # 1) Create any missing tables (audit_logs) — does not touch existing tables.
    SQLModel.metadata.create_all(engine)

    # 2) Add/relax columns on existing tables.
    with engine.begin() as conn:
        for s in stmts:
            conn.execute(text(s))

    print(
        "Schema migration applied: added Phase 0 columns, relaxed legacy blob "
        "columns to NULLable, and ensured audit_logs exists.\n"
        "Next: python -m scripts.migrate_blobs_to_storage"
    )


if __name__ == "__main__":
    migrate(dry_run="--dry-run" in sys.argv)