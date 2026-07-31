"""Transport selection for outbound email.

Render's free plan blocks outbound SMTP, so the Brevo HTTP API must win
whenever it is configured; SMTP is only the fallback.
"""

import app.core.email as email_module
from app.core.email import send_email


def _settings(monkeypatch, **overrides):
    for key, value in overrides.items():
        monkeypatch.setattr(email_module.settings, key, value)


def test_no_transport_configured_logs_and_reports_failure(monkeypatch):
    _settings(monkeypatch, brevo_api_key="", smtp_host="")
    assert send_email("a@b.com", "subj", "body") is False


def test_brevo_preferred_over_smtp(monkeypatch):
    _settings(monkeypatch, brevo_api_key="key-123", smtp_host="smtp.gmail.com")

    captured = {}

    class _Resp:
        status_code = 201
        text = ""

    def fake_post(url, json, headers, timeout):
        captured.update(url=url, json=json, headers=headers)
        return _Resp()

    monkeypatch.setattr(email_module.httpx, "post", fake_post)
    # Any SMTP attempt would be a bug on a host that blocks those ports.
    monkeypatch.setattr(
        email_module.smtplib,
        "SMTP",
        lambda *a, **k: (_ for _ in ()).throw(AssertionError("SMTP must not be used")),
    )

    assert send_email("user@example.com", "subj", "body", "<p>body</p>") is True
    assert captured["url"] == email_module.BREVO_ENDPOINT
    assert captured["headers"]["api-key"] == "key-123"
    assert captured["json"]["to"] == [{"email": "user@example.com"}]
    assert captured["json"]["htmlContent"] == "<p>body</p>"


def test_brevo_error_response_reports_failure(monkeypatch):
    _settings(monkeypatch, brevo_api_key="key-123", smtp_host="")

    class _Resp:
        status_code = 400
        text = '{"message":"Sender not valid"}'

    monkeypatch.setattr(
        email_module.httpx, "post", lambda url, json, headers, timeout: _Resp()
    )
    assert send_email("user@example.com", "subj", "body") is False


def test_falls_back_to_smtp_when_no_brevo_key(monkeypatch):
    _settings(
        monkeypatch,
        brevo_api_key="",
        smtp_host="smtp.example.com",
        smtp_user="",
        smtp_from="MediStore <no-reply@example.com>",
    )

    sent = {}

    class _SMTP:
        def __init__(self, host, port, timeout=None):
            sent["host"] = host
        def __enter__(self):
            return self
        def __exit__(self, *a):
            return False
        def starttls(self):
            pass
        def send_message(self, msg):
            sent["to"] = msg["To"]

    monkeypatch.setattr(email_module.smtplib, "SMTP", _SMTP)
    assert send_email("user@example.com", "subj", "body") is True
    assert sent == {"host": "smtp.example.com", "to": "user@example.com"}


def test_smtp_blocked_port_is_reported_not_raised(monkeypatch):
    """A blocked SMTP port surfaces as False, never an exception into the
    caller — a raise would leak account existence out of /forgot-password."""
    _settings(monkeypatch, brevo_api_key="", smtp_host="smtp.example.com")

    def refuse(*a, **k):
        raise TimeoutError("connection timed out")

    monkeypatch.setattr(email_module.smtplib, "SMTP", refuse)
    assert send_email("user@example.com", "subj", "body") is False
