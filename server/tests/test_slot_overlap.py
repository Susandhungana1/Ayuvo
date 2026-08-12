"""§11: two patients cannot be given the same slot.

`is_slot_available` used to select a single arbitrary overlapping row (no ORDER
BY) and inspect it in Python. With one appointment on file the check was
correct; with two it inspected the oldest — whose end was long past — and let
every subsequent booking through, so a doctor's diary silently accepted several
patients into the same slot. The fix evaluates a bounded overlap predicate in
SQL and locks the matched rows, so a wrongly-accepted request now returns the
400 it always should have returned. `front/` already handles that 400.
"""

import uuid
from datetime import datetime, timedelta, time

from sqlmodel import Session

from app.core.config import engine
from app.models.models import Appointment, DayOfWeek, Doctor, DoctorAvailability, User


def _register(client, name="Someone"):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": name, "email": email, "password": "supersecret1"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["token"], resp.json()["id"]


def _make_doctor(client):
    """A verified, bookable doctor with a published Monday 09:00–11:00 window."""
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

    # A Monday 09:00–11:00 window, 30-minute slots. Two consecutive slots fit.
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


def _user_id_of(client, token):
    resp = client.get("/api/auth/me", headers=_auth(token))
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


def _book(client, patient_token, doctor_id, start):
    return client.post(
        "/api/appointments",
        json={
            "title": "Checkup",
            "doctor_id": doctor_id,
            "doctor_name": "Dr Slot",
            "appointment_date": start.isoformat(),
            "duration_minutes": 30,
            "reason": "Routine",
        },
        headers=_auth(patient_token),
    )


def test_second_booking_into_the_same_slot_is_rejected(client):
    doctor_token, doctor_id = _make_doctor(client)
    patient1_token, _ = _register(client, "Patient One")
    patient2_token, _ = _register(client, "Patient Two")
    slot = _next_monday_0900()

    first = _book(client, patient1_token, doctor_id, slot)
    assert first.status_code == 200, first.text

    second = _book(client, patient2_token, doctor_id, slot)
    assert second.status_code == 400, second.text
    assert "not available" in second.json()["detail"]


def test_adjacent_slot_still_books_after_one_is_taken(client):
    """The bounded predicate must reject overlap but allow the next slot."""
    doctor_token, doctor_id = _make_doctor(client)
    patient1_token, _ = _register(client, "Patient One")
    patient2_token, _ = _register(client, "Patient Two")
    slot = _next_monday_0900()

    assert _book(client, patient1_token, doctor_id, slot).status_code == 200
    # 09:30, immediately after the taken 09:00–09:30 slot — must still book.
    next_slot = slot + timedelta(minutes=30)
    assert _book(client, patient2_token, doctor_id, next_slot).status_code == 200


def test_a_cancelled_slot_can_be_rebooked(client):
    """CANCELLED rows must not block the slot."""
    doctor_token, doctor_id = _make_doctor(client)
    patient1_token, patient1_id = _register(client, "Patient One")
    patient2_token, _ = _register(client, "Patient Two")
    slot = _next_monday_0900()

    resp = _book(client, patient1_token, doctor_id, slot)
    assert resp.status_code == 200, resp.text
    appt_id = resp.json()["id"]

    resp = client.patch(
        f"/api/appointments/{appt_id}/status?status=CANCELLED",
        headers=_auth(patient1_token),
    )
    assert resp.status_code == 200, resp.text

    assert _book(client, patient2_token, doctor_id, slot).status_code == 200


def test_regression_slot_inside_a_past_appointment_is_fine(client):
    """The original bug's exact scenario, from the notes: a doctor with one
    appointment whose end is already past must still accept a fresh booking
    into a different (later) slot — while rejecting a fresh booking into the
    same slot."""
    doctor_token, doctor_id = _make_doctor(client)
    patient1_token, _ = _register(client, "Patient One")
    patient2_token, _ = _register(client, "Patient Two")

    # A past appointment, same doctor.
    past = _next_monday_0900() - timedelta(days=7)
    with Session(engine) as db:
        db.add(
            Appointment(
                user_id=_user_id_of(client, patient1_token),
                doctor_id=doctor_id,
                title="Old",
                appointment_date=past,
                duration_minutes=30,
            )
        )
        db.commit()

    slot = _next_monday_0900()
    first = _book(client, patient2_token, doctor_id, slot)
    assert first.status_code == 200, first.text

    second = _book(client, patient2_token, doctor_id, slot)
    assert second.status_code == 400, second.text
