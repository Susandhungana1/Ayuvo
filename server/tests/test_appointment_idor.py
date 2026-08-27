"""Regression test for appointment IDOR — Strix flagged DELETE /api/appointments/:id.

The backend must ensure users can only delete their own appointments.
Even though the check exists in app/api/appointments.py:478, this test
prevents future regression.
"""

from datetime import datetime, timedelta


def test_user_cannot_delete_other_users_appointment(client):
    # Two users register
    a = client.post("/api/auth/register", json={
        "name": "Alice", "email": "alice-idor@example.com", "password": "Password123!"
    }).json()
    b = client.post("/api/auth/register", json={
        "name": "Bob", "email": "bob-idor@example.com", "password": "Password123!"
    }).json()

    # Alice creates an appointment
    appt = client.post(
        "/api/appointments",
        json={
            "title": "Alice checkup",
            "appointment_date": (datetime.now() + timedelta(days=2)).isoformat(),
            "duration_minutes": 30,
        },
        headers={"Authorization": f"Bearer {a['token']}"},
    )
    assert appt.status_code == 200, appt.text
    appt_id = appt.json()["id"]

    # Bob tries to delete Alice's appointment — must 404, not 200
    resp = client.delete(
        f"/api/appointments/{appt_id}",
        headers={"Authorization": f"Bearer {b['token']}"},
    )
    assert resp.status_code == 404, resp.text

    # Alice can still delete her own
    resp = client.delete(
        f"/api/appointments/{appt_id}",
        headers={"Authorization": f"Bearer {a['token']}"},
    )
    assert resp.status_code == 200, resp.text


def test_user_cannot_update_other_users_appointment(client):
    a = client.post("/api/auth/register", json={
        "name": "Alice2", "email": "alice2-idor@example.com", "password": "Password123!"
    }).json()
    b = client.post("/api/auth/register", json={
        "name": "Bob2", "email": "bob2-idor@example.com", "password": "Password123!"
    }).json()

    appt = client.post(
        "/api/appointments",
        json={
            "title": "Alice2 checkup",
            "appointment_date": (datetime.now() + timedelta(days=3)).isoformat(),
            "duration_minutes": 30,
        },
        headers={"Authorization": f"Bearer {a['token']}"},
    )
    assert appt.status_code == 200, appt.text
    appt_id = appt.json()["id"]

    # Bob tries to update Alice's appointment
    resp = client.put(
        f"/api/appointments/{appt_id}",
        json={
            "title": "Hijacked",
            "appointment_date": (datetime.now() + timedelta(days=3)).isoformat(),
            "duration_minutes": 30,
        },
        headers={"Authorization": f"Bearer {b['token']}"},
    )
    assert resp.status_code == 404, resp.text
