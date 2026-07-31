"""Outbound email, over an HTTP API or plain SMTP.

Two transports because hosting gets in the way: Render's free plan blocks
outbound SMTP ports (25/465/587) outright, so on that plan an SMTP send can
only ever time out. The Brevo HTTP API goes over ordinary HTTPS on 443, which
is not blocked, so it is preferred whenever a key is configured.

Deliberately minimal: one public function, no templating engine.
"""

import logging
import smtplib
from email.message import EmailMessage
from email.utils import parseaddr

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

BREVO_ENDPOINT = "https://api.brevo.com/v3/smtp/email"


def send_email(to: str, subject: str, text: str, html: str | None = None) -> bool:
    """Send an email. Returns True if a provider accepted it, False otherwise.

    Never raises: callers like password reset must not leak send failures to
    the client (that would reveal whether an account exists).
    """
    if settings.brevo_api_key:
        return _send_via_brevo(to, subject, text, html)
    if settings.smtp_host:
        return _send_via_smtp(to, subject, text, html)

    logger.warning(
        "No email transport configured; email to %s not sent.\nSubject: %s\n%s",
        to, subject, text,
    )
    return False


def _sender() -> tuple[str, str]:
    """Split SMTP_FROM ("MediStore <a@b.com>" or "a@b.com") into name, address."""
    name, address = parseaddr(settings.smtp_from)
    return name or "MediStore", address or settings.smtp_from


def _send_via_brevo(to: str, subject: str, text: str, html: str | None) -> bool:
    name, address = _sender()
    payload = {
        "sender": {"name": name, "email": address},
        "to": [{"email": to}],
        "subject": subject,
        "textContent": text,
    }
    if html:
        payload["htmlContent"] = html

    try:
        resp = httpx.post(
            BREVO_ENDPOINT,
            json=payload,
            headers={
                "api-key": settings.brevo_api_key,
                "accept": "application/json",
                "content-type": "application/json",
            },
            timeout=15,
        )
        if resp.status_code >= 400:
            # Body carries the actionable reason, e.g. an unverified sender.
            logger.error(
                "Brevo rejected email to %s: HTTP %s %s",
                to, resp.status_code, resp.text[:500],
            )
            return False
        return True
    except Exception:
        logger.exception("Failed to send email to %s via Brevo", to)
        return False


def _send_via_smtp(to: str, subject: str, text: str, html: str | None) -> bool:
    msg = EmailMessage()
    msg["From"] = settings.smtp_from
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(text)
    if html:
        msg.add_alternative(html, subtype="html")

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as smtp:
            smtp.starttls()
            if settings.smtp_user:
                smtp.login(settings.smtp_user, settings.smtp_password)
            smtp.send_message(msg)
        return True
    except OSError:
        # A timeout here on a host that blocks SMTP egress is not a config
        # error, so name the likely cause rather than leaving a bare traceback.
        logger.exception(
            "SMTP send to %s failed. If this host blocks outbound SMTP "
            "(Render's free plan blocks 25/465/587), set BREVO_API_KEY to send "
            "over HTTPS instead.",
            to,
        )
        return False
    except Exception:
        logger.exception("Failed to send email to %s via SMTP", to)
        return False
