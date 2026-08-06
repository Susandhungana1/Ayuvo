"""The doctor's side of an appointment's status.

PATCH /{id}/status authorises against Appointment.user_id — the patient who
booked — so a doctor calling it always 404s. PATCH /{id}/status/by-doctor is the
doctor-of-record equivalent. These tests cover the happy path, every way it must
refuse, and a regression test proving the original patient route is untouched.
"""

import uuid
from datetime import datetime, timedelta

from sqlmodel import Session, select

from app.core.config import engine
from app.models.models import Appointment, Doctor, User


def _register(client, name="Someone"):
    """A fresh account. Returns (token, user_id)."""
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": name, "email": email, "password": "supersecret1"},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    return body["token"], body["id"]


def _make_doctor(client, name="Dr Who"):
    """A registered user promoted to DOCTOR with a doctor profile.

    Role elevation is a database operation in this product (see
    ADD_DOCTOR_GUIDE.txt), so the test does what an operator would.
    """
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


def _book(client, patient_token, doctor_id):
    """An appointment for `doctor_id`, inserted directly.

    POST /api/appointments enforces that the slot sits inside a published
    availability window; that rule is exercised elsewhere and is not what these
    tests are about.
    """
    appt = Appointment(
        user_id=_user_id_of(client, patient_token),
        doctor_id=doctor_id,
        title="Annual checkup",
        appointment_date=datetime.utcnow() + timedelta(days=3),
        duration_minutes=30,
    )
    with Session(engine) as db:
        db.add(appt)
        db.commit()
        db.refresh(appt)
        return appt.id


def _user_id_of(client, token):
    resp = client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


# --- The new route ---


def test_doctor_of_record_can_confirm(client):
    doctor_token, doctor_id = _make_doctor(client)
    patient_token, _ = _register(client, "Patient")
    appt_id = _book(client, patient_token, doctor_id)

    resp = client.patch(
        f"/api/appointments/{appt_id}/status/by-doctor?status=CONFIRMED",
        headers=_auth(doctor_token),
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "CONFIRMED"

    with Session(engine) as db:
        assert db.get(Appointment, appt_id).status == "CONFIRMED"


def test_doctor_can_complete_and_cancel(client):
    doctor_token, doctor_id = _make_doctor(client)
    patient_token, _ = _register(client, "Patient")
    appt_id = _book(client, patient_token, doctor_id)

    for status in ("CONFIRMED", "COMPLETED", "CANCELLED"):
        resp = client.patch(
            f"/api/appointments/{appt_id}/status/by-doctor?status={status}",
            headers=_auth(doctor_token),
        )
        assert resp.status_code == 200, resp.text
        assert resp.json()["status"] == status


# --- Authorization failures ---


def test_another_doctor_cannot_touch_it(client):
    _, doctor_id = _make_doctor(client, "Dr Owner")
    other_token, _ = _make_doctor(client, "Dr Stranger")
    patient_token, _ = _register(client, "Patient")
    appt_id = _book(client, patient_token, doctor_id)

    resp = client.patch(
        f"/api/appointments/{appt_id}/status/by-doctor?status=CANCELLED",
        headers=_auth(other_token),
    )
    # 404, not 403: the response must not confirm the id exists elsewhere.
    assert resp.status_code == 404, resp.text

    with Session(engine) as db:
        assert db.get(Appointment, appt_id).status == "PENDING"


def test_patient_cannot_use_the_doctor_route(client):
    _, doctor_id = _make_doctor(client)
    patient_token, _ = _register(client, "Patient")
    appt_id = _book(client, patient_token, doctor_id)

    resp = client.patch(
        f"/api/appointments/{appt_id}/status/by-doctor?status=CONFIRMED",
        headers=_auth(patient_token),
    )
    assert resp.status_code == 403, resp.text

    with Session(engine) as db:
        assert db.get(Appointment, appt_id).status == "PENDING"


def test_doctor_role_without_a_profile_is_refused(client):
    token, user_id = _register(client, "Unprofiled")
    with Session(engine) as db:
        user = db.get(User, user_id)
        user.role = "DOCTOR"
        db.add(user)
        db.commit()

    resp = client.patch(
        f"/api/appointments/{uuid.uuid4()}/status/by-doctor?status=CONFIRMED",
        headers=_auth(token),
    )
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Doctor profile not found"


def test_unauthenticated_is_refused(client):
    resp = client.patch(f"/api/appointments/{uuid.uuid4()}/status/by-doctor?status=CONFIRMED")
    assert resp.status_code == 401


# --- Regression: the patient route is unchanged ---


def test_patient_route_still_works_for_its_owner(client):
    """The original endpoint front/ calls, behaving exactly as before."""
    _, doctor_id = _make_doctor(client)
    patient_token, _ = _register(client, "Patient")
    appt_id = _book(client, patient_token, doctor_id)

    resp = client.patch(
        f"/api/appointments/{appt_id}/status?status=CANCELLED",
        headers=_auth(patient_token),
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "CANCELLED"


def test_patient_route_still_404s_for_a_doctor(client):
    """Unchanged too — the reason the second route had to exist."""
    doctor_token, doctor_id = _make_doctor(client)
    patient_token, _ = _register(client, "Patient")
    appt_id = _book(client, patient_token, doctor_id)

    resp = client.patch(
        f"/api/appointments/{appt_id}/status?status=CONFIRMED",
        headers=_auth(doctor_token),
    )
    assert resp.status_code == 404


def test_doctor_inbox_lists_the_appointment(client):
    """The screen these status changes belong to still loads."""
    doctor_token, doctor_id = _make_doctor(client)
    patient_token, _ = _register(client, "Patient")
    appt_id = _book(client, patient_token, doctor_id)

    resp = client.get(
        "/api/appointments/doctor/my-appointments", headers=_auth(doctor_token)
    )
    assert resp.status_code == 200, resp.text
    assert appt_id in [a["id"] for a in resp.json()["appointments"]]
