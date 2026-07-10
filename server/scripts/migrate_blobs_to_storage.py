"""One-off migration: move existing file blobs from Postgres into object storage.

Phase 0 requires that medical file bytes live in object storage, not in the
database. New uploads already do this; this script backfills rows created before
the change.

For every MedicalReport / MedicalFile that still has an inline blob and no
storage_key, it uploads the bytes to the configured STORAGE_BACKEND, records the
returned key, and clears the blob column.

Safe to run repeatedly (idempotent): rows that already have a storage_key are
skipped.

Usage:
    cd server
    python -m scripts.migrate_blobs_to_storage           # migrate
    python -m scripts.migrate_blobs_to_storage --dry-run  # report only
"""

import sys

from sqlmodel import Session, select

from app.core.config import engine
from app.core import storage
from app.models.models import MedicalReport, MedicalFile


def migrate(dry_run: bool = False) -> None:
    moved_reports = moved_files = 0

    with Session(engine) as db:
        reports = db.exec(
            select(MedicalReport).where(MedicalReport.storage_key.is_(None))
        ).all()
        for r in reports:
            if not r.file_content:
                continue
            if dry_run:
                moved_reports += 1
                continue
            key = storage.save_file(
                r.file_content, original_name=r.file_name, prefix="reports",
                content_type=r.file_content_type,
            )
            r.storage_key = key
            r.file_content = None
            db.add(r)
            moved_reports += 1

        files = db.exec(
            select(MedicalFile).where(MedicalFile.storage_key.is_(None))
        ).all()
        for f in files:
            if not f.content:
                continue
            if dry_run:
                moved_files += 1
                continue
            key = storage.save_file(
                f.content, original_name=f.name, prefix="documents",
                content_type=f.content_type,
            )
            f.storage_key = key
            f.content = None
            db.add(f)
            moved_files += 1

        if not dry_run:
            db.commit()

    verb = "Would migrate" if dry_run else "Migrated"
    print(f"{verb} {moved_reports} report blob(s) and {moved_files} document file blob(s).")


if __name__ == "__main__":
    migrate(dry_run="--dry-run" in sys.argv)