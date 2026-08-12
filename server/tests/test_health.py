"""The /health probe.

It reports the active mail transport because /forgot-password deliberately
answers the same way whether or not mail went out — so an unset key on the
host looks exactly like success, and the only symptom is a reset email that
never arrives. This makes that state one curl away.
"""

import app.core.config as config_module


def _transport(client, monkeypatch, *, brevo="", smtp=""):
    monkeypatch.setattr(config_module.settings, "brevo_api_key", brevo)
    monkeypatch.setattr(config_module.settings, "smtp_host", smtp)
    return client.get("/health").json()["email"]


def test_health_reports_database(client):
    body = client.get("/health").json()
    assert body["status"] == "ok"
    assert body["database"] is True


def test_health_reports_no_mail_transport(client, monkeypatch):
    assert _transport(client, monkeypatch) == "none"


def test_health_reports_brevo(client, monkeypatch):
    assert _transport(client, monkeypatch, brevo="key-123", smtp="smtp.gmail.com") == "brevo"


def test_health_reports_smtp_fallback(client, monkeypatch):
    assert _transport(client, monkeypatch, smtp="smtp.gmail.com") == "smtp"


def test_health_never_exposes_the_key(client, monkeypatch):
    monkeypatch.setattr(config_module.settings, "brevo_api_key", "xkeysib-secret-value")
    assert "xkeysib" not in client.get("/health").text


def test_health_reports_the_caretaker_flag(client):
    """The care routes need auth, so an anonymous 401 looks identical whether
    the feature is on or off. /health is the only way to confirm from outside
    that a flag flip actually reached the running process."""
    from app.core.config import settings

    assert client.get("/health").json()["caretaker"] is False

    settings.caretaker_enabled = True
    try:
        assert client.get("/health").json()["caretaker"] is True
    finally:
        settings.caretaker_enabled = False


def test_health_reports_doctor_confirms_bookings_flag(client):
    """Same reasoning as the caretaker flag: the booking default is invisible
    from outside except through /health."""
    from app.core.config import settings

    assert client.get("/health").json()["doctor_confirms_bookings"] is False

    settings.doctor_confirms_bookings = True
    try:
        assert client.get("/health").json()["doctor_confirms_bookings"] is True
    finally:
        settings.doctor_confirms_bookings = False


def test_health_reports_frontend_url(client):
    """The mobile app builds QR codes against a hostname; /health is where the
    server says which one the deployment serves."""
    from app.core.config import settings

    assert client.get("/health").json()["frontend_url"] == settings.frontend_url
    assert client.get("/health").json()["frontend_url"].startswith("http")
