"""User ID generator for #hosxxx format"""
from sqlmodel import Session, select, create_engine
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
    """Generate a new user ID in format #hosxxx"""
    engine = _get_engine()

    with Session(engine) as session:
        # Get or create counter
        counter = session.get(IDCounter, 1)
        if not counter:
            counter = IDCounter(id=1, last_number=0)
            session.add(counter)
            session.commit()
            session.refresh(counter)

        # Increment counter
        counter.last_number += 1
        new_number = counter.last_number
        session.add(counter)
        session.commit()

    # Format as #hosxxx (3 digits with leading zeros)
    return f"#hos{new_number:03d}"
