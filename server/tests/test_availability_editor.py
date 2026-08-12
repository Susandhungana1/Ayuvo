"""§13: the availability editor must reject the same things on update that
create rejects.

`PUT /availability/{id}` used to apply whatever it was given, so an edit could
produce the very overlap the create path exists to prevent — and it could not
move a window to another day. Neither path checked end-after-start, so a
17:00–09:00 window was silently unbookable. Approved: run the overlap check in
the update path, enforce end-after-start on both schemas, and let the update
body carry `day_of_week`.
"""

import uuid

from sqlmodel import Session

from app.core.config import engine
from app.models.models import DayOfWeek, Doctor, DoctorAvailability, User


def _register(client, name="Someone"):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": name, "email": email, "password": "supersecret1"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["token"], resp.json()["id"]


def _make_doctor(client):
    token, user_id = _register(client, "Dr Avail")

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
    return token


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _add(client, token, day="MONDAY", start="09:00", end="11:00"):
    resp = client.post(
        "/api/doctors/availability",
        json={
            "day_of_week": day,
            "start_time": start,
            "end_time": end,
            "slot_duration_minutes": 30,
        },
        headers=_auth(token),
    )
    return resp


def test_create_still_rejects_an_overlapping_window(client):
    token = _make_doctor(client)
    assert _add(client, token).status_code == 200

    resp = _add(client, token, start="10:00", end="12:00")
    assert resp.status_code == 400
    assert "Overlapping" in resp.json()["detail"]


def test_update_rejects_an_overlap_it_would_just_create(client):
    """The regression §13 exists for: edit one window to collide with another."""
    token = _make_doctor(client)
    assert _add(client, token, start="09:00", end="11:00").status_code == 200
    second = _add(client, token, start="14:00", end="16:00")
    assert second.status_code == 200
    second_id = second.json()["id"]

    resp = client.put(
        f"/api/doctors/availability/{second_id}",
        json={"start_time": "10:00", "end_time": "12:00"},
        headers=_auth(token),
    )
    assert resp.status_code == 400
    assert "Overlapping" in resp.json()["detail"]


def test_update_an_edit_that_keeps_a_window_free_still_succeeds(client):
    token = _make_doctor(client)
    assert _add(client, token, start="09:00", end="11:00").status_code == 200
    second = _add(client, token, start="14:00", end="16:00")
    second_id = second.json()["id"]

    resp = client.put(
        f"/api/doctors/availability/{second_id}",
        json={"start_time": "11:30", "end_time": "13:00"},
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["start_time"] == "11:30:00"
    assert resp.json()["end_time"] == "13:00:00"


def test_update_can_move_a_window_to_another_day(client):
    token = _make_doctor(client)
    first = _add(client, token, day="MONDAY", start="09:00", end="11:00")
    second = _add(client, token, day="WEDNESDAY", start="09:00", end="11:00")
    assert first.status_code == 200 and second.status_code == 200
    second_id = second.json()["id"]

    resp = client.put(
        f"/api/doctors/availability/{second_id}",
        json={"day_of_week": "TUESDAY"},
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["day_of_week"] == "TUESDAY"


def test_update_cannot_move_onto_a_day_already_taken(client):
    token = _make_doctor(client)
    assert _add(client, token, day="MONDAY", start="09:00", end="11:00").status_code == 200
    second = _add(client, token, day="TUESDAY", start="09:00", end="11:00")
    second_id = second.json()["id"]

    resp = client.put(
        f"/api/doctors/availability/{second_id}",
        json={"day_of_week": "MONDAY", "start_time": "09:00", "end_time": "11:00"},
        headers=_auth(token),
    )
    assert resp.status_code == 400
    assert "Overlapping" in resp.json()["detail"]


def test_update_itself_does_not_overlap_itself(client):
    """Editing a window to a new shape must not trip on its own current row."""
    token = _make_doctor(client)
    first = _add(client, token, start="09:00", end="11:00")
    first_id = first.json()["id"]

    resp = client.put(
        f"/api/doctors/availability/{first_id}",
        json={"start_time": "09:30", "end_time": "11:30"},
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text


def test_create_rejects_end_before_start(client):
    resp = _add(client, _make_doctor(client), start="17:00", end="09:00")
    assert resp.status_code == 422


def test_update_rejects_end_before_start(client):
    token = _make_doctor(client)
    first = _add(client, token, start="09:00", end="11:00")
    first_id = first.json()["id"]

    resp = client.put(
        f"/api/doctors/availability/{first_id}",
        json={"start_time": "17:00", "end_time": "09:00"},
        headers=_auth(token),
    )
    assert resp.status_code == 400
    assert "after start" in resp.json()["detail"]


def test_update_rejects_end_after_start_when_only_the_end_changes(client):
    """The merged check: end moved earlier than the existing start is invalid."""
    token = _make_doctor(client)
    first = _add(client, token, start="09:00", end="11:00")
    first_id = first.json()["id"]

    resp = client.put(
        f"/api/doctors/availability/{first_id}",
        json={"end_time": "08:00"},
        headers=_auth(token),
    )
    assert resp.status_code == 400
    assert "after start" in resp.json()["detail"]
