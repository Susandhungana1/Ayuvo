"""Retire the `dependents` table left behind by the removed Family feature.

The Family section was replaced by Caretakers. Its router and page are gone,
so nothing reads or writes `dependents` any more — but the rows are still
there, and they are health records: a named person's blood type, allergies and
medical conditions. This script does not throw them away silently.

It exports every row to a timestamped JSON file, verifies the file is readable
and has the expected row count, and only then drops the table. If the export
fails for any reason, nothing is dropped.

    cd server
    python -m scripts.drop_dependents --dry-run   # count rows, write nothing
    python -m scripts.drop_dependents --export    # export only, keep the table
    python -m scripts.drop_dependents --drop      # export, verify, then drop

`--drop` is deliberately not the default: running this with no flag shows you
what is there and stops. The dropped table cannot be recovered from the
database afterwards — only from the export file, so keep it somewhere safe.
"""

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import inspect, text

from app.core.config import engine

TABLE = "dependents"


def _rows(conn) -> list[dict]:
    result = conn.execute(text(f"SELECT * FROM {TABLE} ORDER BY created_at"))
    return [
        {k: (v.isoformat() if isinstance(v, datetime) else v) for k, v in row._mapping.items()}
        for row in result
    ]


def main(argv: list[str]) -> int:
    dry_run = "--dry-run" in argv
    do_drop = "--drop" in argv
    do_export = "--export" in argv or do_drop

    if engine.dialect.name != "postgresql":
        print(
            f"Refusing to run: this targets PostgreSQL, but DATABASE_URL points "
            f"at '{engine.dialect.name}'."
        )
        return 1

    host = engine.url.host or "(local)"
    print(f"Target: {engine.url.render_as_string(hide_password=True)}")

    if not inspect(engine).has_table(TABLE):
        print(f"Table '{TABLE}' does not exist — nothing to do.")
        return 0

    with engine.connect() as conn:
        rows = _rows(conn)
    print(f"Rows in {TABLE}: {len(rows)}")

    if dry_run or not (do_export or do_drop):
        print("\nNothing written. Re-run with --export to save a copy, or "
              "--drop to export and then drop the table.")
        return 0

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    # The filename pattern is gitignored — this file holds names, blood types
    # and medical conditions, and must never reach the repository.
    out = Path(f"dependents_backup_{host.split('.')[0]}_{stamp}.json")
    out.write_text(json.dumps(rows, indent=2, ensure_ascii=False))

    # Read it back rather than trusting the write: this file is the only copy
    # that will survive the drop.
    check = json.loads(out.read_text())
    if len(check) != len(rows):
        print(f"ABORT: export verify failed ({len(check)} != {len(rows)}). "
              f"Table left untouched.")
        return 1
    print(f"Exported {len(check)} row(s) -> {out.resolve()}")

    if not do_drop:
        print("Export only; table kept. Re-run with --drop to remove it.")
        return 0

    with engine.begin() as conn:
        conn.execute(text(f"DROP TABLE {TABLE}"))
    print(
        f"Dropped '{TABLE}'. The rows now exist ONLY in {out.name} — "
        f"store it somewhere durable.\n"
        f"Remember to delete the Dependent model from app/models/models.py, "
        f"or the next create_all() will recreate the table empty."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
