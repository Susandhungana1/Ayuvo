"""Tests for POST /api/auth/change-password."""


def test_change_password_success(client):
    reg = client.post("/api/auth/register", json={
        "name": "Pwd Changer",
        "email": "pwd-change@example.com",
        "password": "OldPass123!",
    })
    assert reg.status_code == 200, reg.text
    token = reg.json()["token"]

    resp = client.post(
        "/api/auth/change-password",
        json={"current_password": "OldPass123!", "new_password": "NewPass456!"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["message"] == "Password updated"

    # Old password no longer works
    login_old = client.post("/api/auth/login", data={
        "username": "pwd-change@example.com",
        "password": "OldPass123!",
    })
    assert login_old.status_code == 401

    # New password works
    login_new = client.post("/api/auth/login", data={
        "username": "pwd-change@example.com",
        "password": "NewPass456!",
    })
    assert login_new.status_code == 200


def test_change_password_wrong_current(client):
    reg = client.post("/api/auth/register", json={
        "name": "Pwd Wrong",
        "email": "pwd-wrong@example.com",
        "password": "Correct123!",
    })
    token = reg.json()["token"]

    resp = client.post(
        "/api/auth/change-password",
        json={"current_password": "WrongPass!", "new_password": "NewPass456!"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 400
    assert "incorrect" in resp.json()["detail"].lower()


def test_change_password_too_short(client):
    reg = client.post("/api/auth/register", json={
        "name": "Pwd Short",
        "email": "pwd-short@example.com",
        "password": "ValidPass1!",
    })
    token = reg.json()["token"]

    resp = client.post(
        "/api/auth/change-password",
        json={"current_password": "ValidPass1!", "new_password": "short"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422  # validation error


def test_change_password_requires_auth(client):
    resp = client.post(
        "/api/auth/change-password",
        json={"current_password": "x", "new_password": "y"},
    )
    assert resp.status_code in (401, 403)
