"""Step 1: the authorization helper in isolation.

These exercise resolve_medicine_scope and the code utilities directly against
the session, with no HTTP layer, so a failure here points at the rule itself
rather than at routing or serialization.
"""

import uuid
from datetime import datetime, timedelta

import pytest
from fastapi import HTTPException
from sqlmodel import Session

from app.core import care
from app.core.config import engine
from app.models.models import CareInvite, CareLink, User


def _user(db: Session, name: str = "Test") -> User:
    user = User(
        name=name,
        email=f"{uuid.uuid4().hex[:10]}@example.com",
        password="x",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def db(_prepare_db):
    with Session(engine) as session:
        yield session


@pytest.fixture(autouse=True)
def caretaker_on():
    """Cross-account scope only exists while the feature flag is on."""
    from app.core.config import settings

    settings.caretaker_enabled = True
    yield
    settings.caretaker_enabled = False


def _link(db: Session, patient: User, caretaker: User, status: str = "active") -> CareLink:
    link = CareLink(
        patient_id=patient.id, caretaker_id=caretaker.id, status=status
    )
    db.add(link)
    db.commit()
    db.refresh(link)
    return link


# --- resolve_medicine_scope ---


def test_omitted_patient_id_resolves_to_self(db):
    """The pre-caretaker call shape: no patient_id means my own medicines."""
    actor = _user(db)
    assert care.resolve_medicine_scope(db, actor_id=actor.id, patient_id=None) == actor.id


def test_own_id_resolves_to_self_without_a_link(db):
    actor = _user(db)
    scope = care.resolve_medicine_scope(db, actor_id=actor.id, patient_id=actor.id)
    assert scope == actor.id


def test_active_link_grants_scope(db):
    patient, caretaker = _user(db, "Ram"), _user(db, "Sita")
    _link(db, patient, caretaker)
    scope = care.resolve_medicine_scope(
        db, actor_id=caretaker.id, patient_id=patient.id
    )
    assert scope == patient.id


def test_no_link_is_403(db):
    patient, stranger = _user(db), _user(db)
    with pytest.raises(HTTPException) as exc:
        care.resolve_medicine_scope(db, actor_id=stranger.id, patient_id=patient.id)
    assert exc.value.status_code == 403


def test_revoked_link_is_403(db):
    patient, caretaker = _user(db), _user(db)
    _link(db, patient, caretaker, status="revoked")
    with pytest.raises(HTTPException) as exc:
        care.resolve_medicine_scope(
            db, actor_id=caretaker.id, patient_id=patient.id
        )
    assert exc.value.status_code == 403


def test_flag_off_denies_even_an_active_link(db):
    """Steps 1-4 ship dark: with the flag off there is no cross-account access,
    including for links left behind by an earlier enabled run."""
    from app.core.config import settings

    patient, caretaker = _user(db), _user(db)
    _link(db, patient, caretaker)

    settings.caretaker_enabled = False
    with pytest.raises(HTTPException) as exc:
        care.resolve_medicine_scope(db, actor_id=caretaker.id, patient_id=patient.id)
    assert exc.value.status_code == 403

    # Own-account access is unaffected by the flag.
    assert care.resolve_medicine_scope(
        db, actor_id=patient.id, patient_id=None
    ) == patient.id


def test_link_direction_is_not_symmetric(db):
    """A cares-for-B link must not let the patient reach the caretaker's list."""
    patient, caretaker = _user(db), _user(db)
    _link(db, patient, caretaker)
    with pytest.raises(HTTPException):
        care.resolve_medicine_scope(
            db, actor_id=patient.id, patient_id=caretaker.id
        )


def test_mutual_caretaking_works_both_ways(db):
    """Two family members each caring for the other: two ordered rows."""
    a, b = _user(db, "A"), _user(db, "B")
    _link(db, a, b)
    _link(db, b, a)
    assert care.resolve_medicine_scope(db, actor_id=b.id, patient_id=a.id) == a.id
    assert care.resolve_medicine_scope(db, actor_id=a.id, patient_id=b.id) == b.id


# --- code helpers ---


def test_generated_codes_avoid_ambiguous_letters(db):
    for _ in range(200):
        assert not (set(care.generate_code()) & set("ILOU"))


def test_generated_code_shape(db):
    code = care.generate_code()
    assert len(code) == care.CODE_LENGTH
    assert care.format_code(code) == f"{code[:4]}-{code[4:]}"


def test_normalize_accepts_lowercase_and_dashes(db):
    code = care.generate_code()
    pasted = f"  {care.format_code(code).lower()}  "
    assert care.normalize_code(pasted) == code
    assert care.hash_code(pasted) == care.hash_code(code)


def test_hash_is_not_the_code(db):
    code = care.generate_code()
    assert care.hash_code(code) != code
    assert len(care.hash_code(code)) == 64


# --- invite lookup ---


def _invite(db: Session, patient: User, code: str, *, ttl=care.INVITE_TTL) -> CareInvite:
    invite = CareInvite(
        patient_id=patient.id,
        code_hash=care.hash_code(code),
        expires_at=datetime.utcnow() + ttl,
    )
    db.add(invite)
    db.commit()
    db.refresh(invite)
    return invite


def test_fresh_invite_is_redeemable(db):
    patient = _user(db)
    code = care.generate_code()
    _invite(db, patient, code)
    assert care.find_redeemable_invite(db, code) is not None


def test_expired_invite_is_not_redeemable(db):
    patient = _user(db)
    code = care.generate_code()
    _invite(db, patient, code, ttl=timedelta(minutes=-1))
    assert care.find_redeemable_invite(db, code) is None


def test_used_invite_is_not_redeemable(db):
    patient = _user(db)
    code = care.generate_code()
    invite = _invite(db, patient, code)
    invite.used_at = datetime.utcnow()
    db.add(invite)
    db.commit()
    assert care.find_redeemable_invite(db, code) is None


def test_unknown_code_is_not_redeemable(db):
    assert care.find_redeemable_invite(db, care.generate_code()) is None


def test_issuing_a_new_code_burns_the_previous_one(db):
    patient = _user(db)
    first, second = care.generate_code(), care.generate_code()
    _invite(db, patient, first)
    care.invalidate_outstanding_invites(db, patient.id)
    _invite(db, patient, second)
    db.commit()

    assert care.find_redeemable_invite(db, first) is None
    assert care.find_redeemable_invite(db, second) is not None
