"""Auth flow tests: registration, login, JWT-protected access, and 2FA."""

import uuid

import pyotp


def _register(client, password="supersecret1"):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": "Test User", "email": email, "password": password},
    )
    return email, resp


def test_register_returns_token(client):
    _, resp = _register(client)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["token"]
    assert body["email"].endswith("@example.com")
    assert body["role"] == "PATIENT"


def test_register_rejects_short_password(client):
    _, resp = _register(client, password="short")
    assert resp.status_code == 422


def test_register_rejects_duplicate_email(client):
    email, resp = _register(client)
    assert resp.status_code == 200
    dup = client.post(
        "/api/auth/register",
        json={"name": "Other", "email": email, "password": "supersecret1"},
    )
    assert dup.status_code == 400


def test_login_success_and_me(client):
    email, _ = _register(client)
    resp = client.post(
        "/api/auth/login",
        data={"username": email, "password": "supersecret1"},
    )
    assert resp.status_code == 200, resp.text
    token = resp.json()["token"]

    me = client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["email"] == email


def test_login_wrong_password(client):
    email, _ = _register(client)
    resp = client.post(
        "/api/auth/login",
        data={"username": email, "password": "wrongpassword"},
    )
    assert resp.status_code == 401


def test_me_requires_auth(client):
    resp = client.get("/api/auth/me")
    assert resp.status_code == 401


def test_2fa_setup_verify_and_enforced_login(client):
    email, reg = _register(client)
    token = reg.json()["token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Enroll
    setup = client.post("/api/auth/2fa/setup", headers=headers)
    assert setup.status_code == 200, setup.text
    secret = setup.json()["secret"]
    assert setup.json()["qr_code_data_uri"].startswith("data:image/png;base64,")

    # Not active until verified
    assert client.get("/api/auth/2fa/status", headers=headers).json()["enabled"] is False

    # Verify with a real code
    code = pyotp.TOTP(secret).now()
    verify = client.post("/api/auth/2fa/verify", json={"code": code}, headers=headers)
    assert verify.status_code == 200
    assert verify.json()["enabled"] is True

    # Login now requires the code: password alone is rejected
    no_code = client.post(
        "/api/auth/login", data={"username": email, "password": "supersecret1"}
    )
    assert no_code.status_code == 401

    # Login with the code (sent via client_secret form field) succeeds
    ok = client.post(
        "/api/auth/login",
        data={
            "username": email,
            "password": "supersecret1",
            "client_secret": pyotp.TOTP(secret).now(),
        },
    )
    assert ok.status_code == 200, ok.text
    assert ok.json()["token"]