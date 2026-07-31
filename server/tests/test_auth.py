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

# --- Password reset ---

def _request_reset(client, monkeypatch, email):
    """Trigger /forgot-password with the outbound email captured instead of sent,
    and return the raw reset token extracted from the emailed link."""
    import re
    import app.api.auth as auth_module

    sent = {}

    def fake_send_email(to, subject, text, html=None):
        sent["to"] = to
        sent["text"] = text
        return True

    monkeypatch.setattr(auth_module, "send_email", fake_send_email)

    resp = client.post("/api/auth/forgot-password", json={"email": email})
    assert resp.status_code == 200, resp.text
    match = re.search(r"token=([A-Za-z0-9_-]+)", sent.get("text", ""))
    return match.group(1) if match else None


def test_forgot_password_unknown_email_is_generic(client):
    resp = client.post(
        "/api/auth/forgot-password", json={"email": "nobody@example.com"}
    )
    # Same 200 + message as for a real account, so emails can't be enumerated.
    assert resp.status_code == 200
    assert "If an account exists" in resp.json()["message"]


def test_password_reset_full_flow(client, monkeypatch):
    email, _ = _register(client)
    token = _request_reset(client, monkeypatch, email)
    assert token, "reset email should contain a token link"

    resp = client.post(
        "/api/auth/reset-password",
        json={"token": token, "new_password": "newsecret99"},
    )
    assert resp.status_code == 200, resp.text

    # Old password no longer works; new one does.
    old = client.post(
        "/api/auth/login", data={"username": email, "password": "supersecret1"}
    )
    assert old.status_code == 401
    new = client.post(
        "/api/auth/login", data={"username": email, "password": "newsecret99"}
    )
    assert new.status_code == 200, new.text

    # Token is single-use.
    again = client.post(
        "/api/auth/reset-password",
        json={"token": token, "new_password": "anotherpass1"},
    )
    assert again.status_code == 400


def test_new_reset_request_invalidates_previous_token(client, monkeypatch):
    email, _ = _register(client)
    first = _request_reset(client, monkeypatch, email)
    second = _request_reset(client, monkeypatch, email)

    resp = client.post(
        "/api/auth/reset-password",
        json={"token": first, "new_password": "newsecret99"},
    )
    assert resp.status_code == 400

    resp = client.post(
        "/api/auth/reset-password",
        json={"token": second, "new_password": "newsecret99"},
    )
    assert resp.status_code == 200, resp.text


def test_reset_rejects_bad_token(client):
    resp = client.post(
        "/api/auth/reset-password",
        json={"token": "definitely-not-a-real-token", "new_password": "newsecret99"},
    )
    assert resp.status_code == 400


def test_reset_rejects_short_password(client, monkeypatch):
    email, _ = _register(client)
    token = _request_reset(client, monkeypatch, email)
    resp = client.post(
        "/api/auth/reset-password",
        json={"token": token, "new_password": "short"},
    )
    assert resp.status_code == 422


def test_reset_email_includes_pasteable_code(client, monkeypatch):
    """The mail carries the bare token as well as the link, so a user whose
    mail client mangled the URL can still paste the code into the reset page."""
    import re
    import app.api.auth as auth_module

    sent = {}
    monkeypatch.setattr(
        auth_module,
        "send_email",
        lambda to, subject, text, html=None: sent.update(text=text, html=html) or True,
    )

    email, _ = _register(client)
    client.post("/api/auth/forgot-password", json={"email": email})

    token = re.search(r"token=([A-Za-z0-9_-]+)", sent["text"]).group(1)
    # Present on its own line, not only inside the URL.
    assert f"\n{token}\n" in sent["text"]
    assert token in sent["html"]

    # And that pasted code actually works.
    resp = client.post(
        "/api/auth/reset-password",
        json={"token": token, "new_password": "newsecret99"},
    )
    assert resp.status_code == 200, resp.text


def test_failed_send_is_audited_but_not_leaked(client, monkeypatch):
    """A dead mail provider must stay invisible to the caller (else it reveals
    the account exists) but must be visible to us in the audit log."""
    from sqlmodel import Session, select

    import app.api.auth as auth_module
    from app.core.config import engine
    from app.models.models import AuditLog

    from app.core.email import SendResult

    monkeypatch.setattr(
        auth_module,
        "send_email",
        lambda to, subject, text, html=None: SendResult(False, "brevo HTTP 401: nope"),
    )

    email, _ = _register(client)
    resp = client.post("/api/auth/forgot-password", json={"email": email})
    assert resp.status_code == 200
    assert "If an account exists" in resp.json()["message"]

    with Session(engine) as db:
        failures = db.exec(
            select(AuditLog).where(AuditLog.action == "auth.reset.email_failed")
        ).all()
    assert failures, "a failed reset email should leave an audit entry"
    # The provider's reason is what makes the entry actionable — without it the
    # entry only says "something broke".
    assert any("401" in (f.detail or "") for f in failures)
