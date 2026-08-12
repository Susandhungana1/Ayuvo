"""§10: a booking with a doctor can be PENDING pending their confirmation.

By default `create_appointment` confirms a booking with a doctor on that
doctor's behalf, which made `PENDING` unreachable in any inbox and let a
doctor's diary fill up without their consent. The `DOCTOR_CONFIRMS_BOOKINGS`
flag defaults off — byte-identical behaviour while off — and when on, a
booking with a doctor is created PENDING for the doctor to accept or reject
through the route phase 5 shipped.
"""

import uuid
from datetime import datetime, timedelta, time

import pytest
from sqlmodel import Session

from app.core.config import engine, settings
from app.models.models import DayOfWeek, Doctor, DoctorAvailability, User


@pytest.fixture
def confirmations_on():
    settings.doctor_confirms_bookings = True
    yield
    settings.doctor_confirms_bookings = False


def _register(client, name="Someone"):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": name, "email": email, "password": "supersecret1"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["token"], resp.json()["id"]


def _make_doctor(client):
    """A bookable doctor with a published Monday 09:00–11:00 window."""
    token, user_id = _register(client, "Dr Slot")

    with Session(engine) as db:
        user = db.get(User, user_id)
        user.role = "DOCTOR"
        db.add(user)
        db.commit()

    resp = client.post(
        "/api/doctors/doctors",
        json={"nmid": f"MD{uuid.uuid4().hex[:6]}", "degree": "MD", "specialty": "General"},
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text
    doctor_id = resp.json()["id"]

    with Session(engine) as db:
        doctor = db.get(Doctor, doctor_id)
        doctor.verified = True
        db.add(doctor)
        db.commit()

    avail = DoctorAvailability(
        doctor_id=doctor_id,
        day_of_week=DayOfWeek.MONDAY,
        start_time=time(9, 0),
        end_time=time(11, 0),
        slot_duration_minutes=30,
        is_available=True,
    )
    with Session(engine) as db:
        db.add(avail)
        db.commit()

    return token, doctor_id


def _next_monday_0900():
    now = datetime.now()
    days_ahead = (0 - now.weekday() + 7) % 7
    if days_ahead == 0:
        days_ahead = 7
    day = (now + timedelta(days=days_ahead)).date()
    return datetime(day.year, day.month, day.day, 9, 0)


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _book(client, patient_token, doctor_id):
    return client.post(
        "/api/appointments",
        json={
            "title": "Checkup",
            "doctor_id": doctor_id,
            "doctor_name": "Dr Slot",
            "appointment_date": _next_monday_0900().isoformat(),
            "duration_minutes": 30,
            "reason": "Routine",
        },
        headers=_auth(patient_token),
    )


def test_default_flag_keeps_confirming_on_the_doctors_behalf(client):
    """Byte-identical to today: no flag set, booking with a doctor is CONFIRMED."""
    doctor_token, doctor_id = _make_doctor(client)
    patient_token, _ = _register(client, "Patient")

    resp = _book(client, patient_token, doctor_id)
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "CONFIRMED"


def test_flag_makes_a_booking_with_a_doctor_pending(client, confirmations_on):
    doctor_token, doctor_id = _make_doctor(client)
    patient_token, _ = _register(client, "Patient")

    resp = _book(client, patient_token, doctor_id)
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "PENDING"

    # The doctor of record sees it in the inbox and can accept it.
    inbox = client.get(
        "/api/appointments/doctor/my-appointments", headers=_auth(doctor_token)
    ).json()["appointments"]
    assert resp.json()["id"] in [a["id"] for a in inbox]

    accept = client.patch(
        f"/api/appointments/{resp.json()['id']}/status/by-doctor?status=CONFIRMED",
        headers=_auth(doctor_token),
    )
    assert accept.status_code == 200, accept.text
    assert accept.json()["status"] == "CONFIRMED"


def test_flag_does_not_change_a_booking_without_a_doctor(client, confirmations_on):
    """A self-scheduled (no doctor) appointment stays PENDING either way."""
    patient_token, _ = _register(client, "Patient")

    resp = client.post(
        "/api/appointments",
        json={
            "title": "Self note",
            "appointment_date": _next_monday_0900().isoformat(),
            "duration_minutes": 30,
        },
        headers=_auth(patient_token),
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "PENDING"


def test_regression_slot_still_rejects_double_booking(client, confirmations_on):
    """The §11 overlap guard must hold while the flag is on too."""
    doctor_token, doctor_id = _make_doctor(client)
    patient1_token, _ = _register(client, "Patient One")
    patient2_token, _ = _register(client, "Patient Two")

    assert _book(client, patient1_token, doctor_id).status_code == 200
    assert _book(client, patient2_token, doctor_id).status_code == 400
