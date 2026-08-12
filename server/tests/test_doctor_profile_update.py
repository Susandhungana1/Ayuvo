"""§12: a doctor can correct their own registration.

`POST /api/doctors` refuses a second profile and there was no PUT, so `nmid`,
`degree` and `specialty` were write-once and a typo needed an operator with
psql. `PUT /api/doctors/me` accepts the same three fields, doctor-role only,
scoped to the caller's own row, and resets `verified` when anything is edited —
the credential an operator verified against is no longer the one on file.
"""

import uuid

from sqlmodel import Session

from app.core.config import engine
from app.models.models import Doctor, User


def _register(client, name="Someone"):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": name, "email": email, "password": "supersecret1"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["token"], resp.json()["id"]


def _make_doctor(client, name="Dr Fixable"):
    token, user_id = _register(client, name)

    with Session(engine) as db:
        user = db.get(User, user_id)
        user.role = "DOCTOR"
        db.add(user)
        db.commit()

    resp = client.post(
        "/api/doctors/doctors",
        json={"nmid": f"MD{uuid.uuid4().hex[:6]}", "degree": "MD", "specialty": "General"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200, resp.text
    return token, resp.json()["id"]


def _verify_doctor(doctor_id):
    with Session(engine) as db:
        doctor = db.get(Doctor, doctor_id)
        doctor.verified = True
        db.add(doctor)
        db.commit()


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def test_doctor_can_correct_their_profile(client):
    token, doctor_id = _make_doctor(client)

    resp = client.put(
        "/api/doctors/doctors/me",
        json={"nmid": "MD654321", "degree": "MBBS", "specialty": "Cardiology"},
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["nmid"] == "MD654321"
    assert resp.json()["degree"] == "MBBS"
    assert resp.json()["specialty"] == "Cardiology"


def test_editing_resets_verified(client):
    token, doctor_id = _make_doctor(client)
    _verify_doctor(doctor_id)

    resp = client.put(
        "/api/doctors/doctors/me", json={"specialty": "Neurology"}, headers=_auth(token)
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["verified"] is False

    with Session(engine) as db:
        assert db.get(Doctor, doctor_id).verified is False


def test_an_empty_put_does_not_unverify(client):
    """A no-op PUT must not silently revoke a working doctor's verification."""
    token, doctor_id = _make_doctor(client)
    _verify_doctor(doctor_id)

    resp = client.put("/api/doctors/doctors/me", json={}, headers=_auth(token))
    assert resp.status_code == 200, resp.text
    assert resp.json()["verified"] is True


def test_partial_update_leaves_other_fields_alone(client):
    token, doctor_id = _make_doctor(client)

    resp = client.put("/api/doctors/doctors/me", json={"specialty": "Pediatrics"}, headers=_auth(token))
    assert resp.status_code == 200, resp.text
    assert resp.json()["degree"] == "MD"
    assert resp.json()["specialty"] == "Pediatrics"


def test_patient_cannot_use_the_doctor_route(client):
    token, _ = _register(client, "Plain User")

    resp = client.put(
        "/api/doctors/doctors/me",
        json={"nmid": "MD000000"},
        headers=_auth(token),
    )
    assert resp.status_code == 403


def test_doctor_without_a_profile_is_refused(client):
    token, user_id = _register(client, "Unprofiled")

    with Session(engine) as db:
        user = db.get(User, user_id)
        user.role = "DOCTOR"
        db.add(user)
        db.commit()

    resp = client.put(
        "/api/doctors/doctors/me", json={"nmid": "MD000000"}, headers=_auth(token)
    )
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Doctor profile not found"


def test_route_does_not_touch_other_doctors_rows(client):
    _, doctor_a_id = _make_doctor(client, "Dr A")
    token_b, _ = _make_doctor(client, "Dr B")

    resp = client.put(
        "/api/doctors/doctors/me", json={"nmid": "MD000001"}, headers=_auth(token_b)
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["id"] != doctor_a_id

    with Session(engine) as db:
        other = db.get(Doctor, doctor_a_id)
        assert other.nmid != "MD000001"


def test_unauthenticated_is_refused(client):
    resp = client.put("/api/doctors/doctors/me", json={"nmid": "MD000000"})
    assert resp.status_code == 401
