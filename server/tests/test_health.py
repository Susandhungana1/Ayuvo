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
