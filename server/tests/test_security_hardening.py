"""Regression tests for the security-hardening pass.

Covers, per finding:

  H1  /api/emergency/public masks third-party contact email + ids
  H2  QR share PIN: per-link failure counter locks the link after 10 tries
  M1  password reset revokes every outstanding refresh token
  M2  a single-report share carries no emergency profile
  M4  uploaded filenames are sanitized out of Content-Disposition (no CRLF
      header injection) and every file response carries nosniff
  L6  report_type is pinned to the enum on upload
"""

import hashlib
import urllib.parse
import uuid
from datetime import datetime, timedelta

from sqlmodel import Session, select

from app.core.config import engine
from app.models.models import PasswordResetToken, User

FILE_BYTES = b"COMPLETE BLOOD COUNT\nHemoglobin 13.5 g/dL\n"


def _register(client, name="Test User"):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": name, "email": email, "password": "supersecret1"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _upload(client, token, name="cbc.txt"):
    resp = client.post(
        "/api/reports",
        files={"file": (name, FILE_BYTES, "text/plain")},
        data={"report_type": "BLOOD_TEST", "notes": "routine"},
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


def _set_emergency_profile(client, token):
    resp = client.put(
        "/api/emergency/profile",
        json={"blood_type": "A+"},
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text
    resp = client.post(
        "/api/emergency/contacts",
        json={"name": "Jane Doe", "phone": "+9779800000000"},
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text


# --- H2: PIN lockout ---------------------------------------------------------

def test_qr_pin_locks_the_link_after_repeated_failures(client):
    owner = _register(client)
    _upload(client, owner["token"])
    link = client.post("/api/share/qr-code", headers=_auth(owner["token"]))
    assert link.status_code == 200, link.text
    token = link.json()["token"]
    pin = link.json()["pin"]

    for _ in range(10):
        resp = client.get(f"/api/share/qr-code/{token}", params={"pin": "000000"})
        assert resp.status_code == 401, resp.text

    # 11th attempt: locked, even with the correct PIN.
    resp = client.get(f"/api/share/qr-code/{token}", params={"pin": pin})
    assert resp.status_code == 410, resp.text


def test_correct_pin_resets_the_failure_counter(client):
    owner = _register(client)
    _upload(client, owner["token"])
    link = client.post("/api/share/qr-code", headers=_auth(owner["token"]))
    token = link.json()["token"]
    pin = link.json()["pin"]

    for _ in range(5):
        assert client.get(
            f"/api/share/qr-code/{token}", params={"pin": "111111"}
        ).status_code == 401

    assert client.get(
        f"/api/share/qr-code/{token}", params={"pin": pin}
    ).status_code == 200

    # Counter was reset by the success: failures start counting again.
    resp = client.get(f"/api/share/qr-code/{token}", params={"pin": "222222"})
    assert resp.status_code == 401, resp.text


# --- M1: password reset revokes refresh tokens -------------------------------

def test_password_reset_revokes_outstanding_refresh_tokens(client):
    owner = _register(client)

    raw_token = "raw_reset_token_%s" % uuid.uuid4().hex
    with Session(engine) as db:
        user = db.exec(select(User).where(User.email == owner["email"])).first()
        assert user is not None
        db.add(PasswordResetToken(
            user_id=user.id,
            token_hash=hashlib.sha256(raw_token.encode()).hexdigest(),
            expires_at=datetime.utcnow() + timedelta(minutes=60),
        ))
        db.commit()

    resp = client.post(
        "/api/auth/reset-password",
        json={"token": raw_token, "new_password": "newsecret99"},
    )
    assert resp.status_code == 200, resp.text

    # The refresh token issued at registration is dead after the reset.
    dead = client.post(
        "/api/auth/refresh",
        json={"refresh_token": owner["refresh_token"]},
    )
    assert dead.status_code == 401, dead.text


# --- H1: public emergency masking --------------------------------------------

def test_public_emergency_hides_contact_email_and_id(client):
    owner = _register(client)
    _set_emergency_profile(client, owner["token"])

    # User ids contain '#' (e.g. #hos014); unencoded, the value is truncated
    # into a URL fragment and the request 404s.
    public_url = "/api/emergency/public/" + urllib.parse.quote(owner["id"], safe="")
    resp = client.get(public_url)
    assert resp.status_code == 200, resp.text
    data = resp.json()

    assert data["blood_type"] == "A+"
    assert len(data["emergency_contacts"]) == 1
    contact = data["emergency_contacts"][0]
    assert contact["name"] == "Jane Doe"
    assert contact["phone"] == "+9779800000000"
    assert "id" not in contact or contact["id"] == ""


# --- M2: single-report shares carry no emergency profile ---------------------

def test_single_report_share_carries_no_emergency_profile(client):
    owner = _register(client)
    _set_emergency_profile(client, owner["token"])
    report_id = _upload(client, owner["token"])

    resp = client.post(f"/api/share/{report_id}", headers=_auth(owner["token"]))
    assert resp.status_code == 200, resp.text

    resp = client.get(f"/api/share/{resp.json()['token']}")
    assert resp.status_code == 200, resp.text
    data = resp.json()

    assert data["report"]["id"] == report_id
    assert data["emergency"]["blood_type"] is None
    assert data["emergency"]["emergency_contacts"] == []


# --- M4: filename sanitization + nosniff -------------------------------------

def test_report_filename_sanitized_in_content_disposition(client):
    owner = _register(client)
    evil_name = 'evil"\r\nX-Injected: 1.pdf'
    resp = client.post(
        "/api/reports",
        files={"file": (evil_name, FILE_BYTES, "text/plain")},
        data={"report_type": "BLOOD_TEST"},
        headers=_auth(owner["token"]),
    )
    assert resp.status_code == 200, resp.text
    report_id = resp.json()["id"]

    file_resp = client.get(f"/api/reports/{report_id}/file", headers=_auth(owner["token"]))
    assert file_resp.status_code == 200, file_resp.text

    disposition = file_resp.headers.get("content-disposition", "")
    # Raw CR/LF must never reach the header (test clients and browsers both
    # percent-encode them on the wire; the sanitizer catches any raw variant).
    assert "\r" not in disposition and "\n" not in disposition
    assert file_resp.headers.get("x-injected") is None
    assert file_resp.headers.get("x-content-type-options") == "nosniff"


def test_unsafe_upload_content_type_served_as_octet_stream(client):
    owner = _register(client)
    resp = client.post(
        "/api/reports",
        files={"file": ("page.html", b"<script>alert(1)</script>", "text/html")},
        data={"report_type": "LAB_REPORT"},
        headers=_auth(owner["token"]),
    )
    assert resp.status_code == 200, resp.text

    file_resp = client.get(
        f"/api/reports/{resp.json()['id']}/file", headers=_auth(owner["token"])
    )
    assert file_resp.status_code == 200, file_resp.text
    assert file_resp.headers["content-type"].startswith("application/octet-stream")


# --- L6: report_type pinned to the enum --------------------------------------

def test_report_upload_rejects_unknown_report_type(client):
    owner = _register(client)
    resp = client.post(
        "/api/reports",
        files={"file": ("cbc.txt", FILE_BYTES, "text/plain")},
        data={"report_type": "<script>alert(1)</script>"},
        headers=_auth(owner["token"]),
    )
    assert resp.status_code == 400, resp.text


# --- Upload memory cap -------------------------------------------------------

def test_oversize_upload_rejected_without_reading_into_ram(client):
    owner = _register(client)
    big = b"x" * (10 * 1024 * 1024 + 1)
    resp = client.post(
        "/api/reports",
        files={"file": ("huge.pdf", big, "application/pdf")},
        data={"report_type": "BLOOD_TEST"},
        headers=_auth(owner["token"]),
    )
    assert resp.status_code == 413, resp.text

    resp = client.post(
        f"/api/documents",
        json={"title": "doc", "document_type": "OTHER"},
        headers=_auth(owner["token"]),
    )
    if resp.status_code == 200:
        doc_id = resp.json()["id"]
        resp = client.post(
            f"/api/documents/{doc_id}/files",
            files={"file": ("huge.png", big, "image/png")},
            headers=_auth(owner["token"]),
        )
        assert resp.status_code == 413, resp.text


# --- Push SSRF guard ---------------------------------------------------------

def test_push_subscribe_rejects_non_https_or_non_global_endpoints(client, monkeypatch):
    owner = _register(client)
    monkeypatch.setattr("app.core.config.settings.vapid_public_key", "PUB", raising=False)
    monkeypatch.setattr("app.core.config.settings.vapid_private_key", "PRIV", raising=False)

    def subscribe(endpoint):
        return client.post(
            "/api/push/subscribe",
            json={"endpoint": endpoint, "keys": {"p256dh": "a", "auth": "b"}},
            headers=_auth(owner["token"]),
        )

    for bad in [
        "http://169.254.169.254/latest/meta-data/",  # cloud metadata
        "http://127.0.0.1:5432/x",                   # loopback
        "http://10.0.0.5/private",                   # RFC1918
        "https://[::1]/x",                           # IPv6 loopback
        "http://example.com/plain-http",             # cleartext
        "https://user:pass@example.com/x",           # credentials in URL
    ]:
        resp = subscribe(bad)
        assert resp.status_code == 400, (bad, resp.text)

    ok = subscribe("https://fcm.googleapis.com/fcm/send/abc")
    assert ok.status_code == 200, ok.text


# --- Reset email HTML escaping ------------------------------------------------

def test_reset_email_escapes_user_name(client, monkeypatch):
    import re

    import app.api.auth as auth_module

    owner = _register(client, name="<script>alert(1)</script>")

    sent = {}

    class _Sent:
        error = None

    def fake_send_email(to, subject, text, html=None):
        sent["to"] = to
        sent["text"] = text
        sent["html"] = html
        return _Sent()

    monkeypatch.setattr(auth_module, "send_email", fake_send_email)

    resp = client.post("/api/auth/forgot-password", json={"email": owner["email"]})
    assert resp.status_code == 200, resp.text

    match = re.search(r"token=([A-Za-z0-9_-]+)", sent.get("text", ""))
    assert match, "reset email should contain a token link"

    reset = client.post(
        "/api/auth/reset-password",
        json={"token": match.group(1), "new_password": "newsecret99"},
    )
    assert reset.status_code == 200, reset.text

    assert "&lt;script&gt;alert(1)&lt;/script&gt;" in sent["html"]
    assert "<script>alert(1)</script>" not in sent["html"]

def test_client_key_prefers_edge_headers_over_peer(client):
    from types import SimpleNamespace

    from app.core.ratelimit import client_key

    class _Req:
        def __init__(self, headers):
            self.headers = headers
            self.client = SimpleNamespace(host="172.16.0.1")

    assert client_key(_Req({"cf-connecting-ip": "203.0.113.9"})) == "ip:203.0.113.9"
    assert (
        client_key(_Req({"x-forwarded-for": "198.51.100.2, 10.0.0.1"}))
        == "ip:198.51.100.2"
    )
    assert client_key(_Req({"x-forwarded-for": "not-an-ip"})) == "ip:172.16.0.1"
    assert client_key(_Req({})) == "ip:172.16.0.1"
