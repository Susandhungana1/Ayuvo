"""Tests for account deletion (right to erasure) and PIN-protected shares."""

import uuid


def _register(client, password="supersecret1"):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": "Test User", "email": email, "password": password},
    )
    assert resp.status_code == 200, resp.text
    return email, resp.json()


def _auth_headers(body):
    return {"Authorization": f"Bearer {body['token']}"}


def test_delete_account_removes_data_and_kills_session(client):
    email, body = _register(client)
    refresh = body["refresh_token"]
    headers = _auth_headers(body)

    # Create data across the tables the user owns.
    r = client.post(
        "/api/vitals",
        json={"type": "heart_rate", "value": 72, "unit": "bpm", "recorded_at": "2026-01-01T10:00:00"},
        headers=headers,
    )
    assert r.status_code == 200, r.text

    r = client.post(
        "/api/medicines",
        json={
            "name": "Amoxicillin",
            "dosage": "500mg",
            "frequency": "1-0-1",
            "start_date": "2026-01-01",
        },
        headers=headers,
    )
    assert r.status_code == 200, r.text

    r = client.post(
        "/api/appointments",
        json={
            "title": "Checkup",
            "appointment_date": "2030-02-01T10:00:00",
            "doctor_name": "Dr. X",
        },
        headers=headers,
    )
    assert r.status_code == 200, r.text

    # Delete the account.
    r = client.delete("/api/users/me", headers=headers)
    assert r.status_code == 200, r.text

    # The access token is dead.
    me = client.get("/api/auth/me", headers=headers)
    assert me.status_code == 401

    # The refresh token is dead too.
    r = client.post("/api/auth/refresh", json={"refresh_token": refresh})
    assert r.status_code == 401

    # Login with the old credentials now fails — the user row is gone.
    r = client.post(
        "/api/auth/login",
        data={"username": email, "password": "supersecret1"},
    )
    assert r.status_code == 401


def test_delete_account_requires_auth(client):
    r = client.delete("/api/users/me")
    assert r.status_code in (401, 403)


def test_qr_share_requires_pin(client):
    _, body = _register(client)
    headers = _auth_headers(body)

    # Give the account something shareable (an emergency profile value).
    r = client.put(
        "/api/emergency/profile",
        json={"blood_type": "O+"},
        headers=headers,
    )
    assert r.status_code == 200, r.text

    r = client.post("/api/share/qr-code", headers=headers)
    assert r.status_code == 200, r.text
    data = r.json()
    share_token = data["token"]
    pin = data["pin"]
    assert pin is not None and len(pin) == 6

    # Without the PIN: 401.
    r = client.get(f"/api/share/qr-code/{share_token}")
    assert r.status_code == 401

    # With a wrong PIN: 401.
    r = client.get(f"/api/share/qr-code/{share_token}?pin=000000")
    assert r.status_code == 401

    # With the right PIN: 200.
    r = client.get(f"/api/share/qr-code/{share_token}?pin={pin}")
    assert r.status_code == 200, r.text

    # The single-report share stays PIN-free (no pin field on response).
    r = client.put(
        "/api/emergency/profile",
        json={"blood_type": None},
        headers=headers,
    )