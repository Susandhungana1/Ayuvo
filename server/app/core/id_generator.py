"""User ID generator for #hosxxx format"""
from sqlmodel import Session, select, create_engine, text
from app.models.models import IDCounter
from app.core.config import settings

# Create a separate engine for ID generation to avoid circular imports
_id_engine = None


def _get_engine():
    global _id_engine
    if _id_engine is None:
        _id_engine = create_engine(settings.database_url, echo=False)
    return _id_engine


def generate_user_id() -> str:
    """Generate a new user ID in format #hosxxx.

    Uses ``SELECT ... FOR UPDATE`` to lock the counter row for the duration
    of the transaction, preventing two concurrent registrations from receiving
    the same number.
    """
    engine = _get_engine()

    with Session(engine) as session:
        # Upsert atomically: insert the counter if missing, then increment.
        # ``RETURNING`` gives us the new value in one round-trip with no race.
        result = session.execute(
            text(
                "INSERT INTO id_counter (id, last_number) VALUES (1, 1) "
                "ON CONFLICT (id) DO UPDATE SET last_number = id_counter.last_number + 1 "
                "RETURNING last_number"
            )
        )
        new_number = result.fetchone()[0]
        session.commit()

    # Format as #hosxxx (3 digits with leading zeros)
    return f"#hos{new_number:03d}"
