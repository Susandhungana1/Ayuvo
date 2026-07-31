"""Outbound email via plain SMTP.

Deliberately minimal: one function, no templating engine. When SMTP is not
configured (local dev), the message is logged instead of sent so flows like
password reset remain testable without a mail provider.
"""

import logging
import smtplib
from email.message import EmailMessage

from app.core.config import settings

logger = logging.getLogger(__name__)


def send_email(to: str, subject: str, text: str, html: str | None = None) -> bool:
    """Send an email. Returns True if handed off to SMTP, False otherwise.

    Never raises: callers like password reset must not leak send failures
    to the client (that would reveal whether an account exists).
    """
    if not settings.email_enabled:
        logger.warning(
            "SMTP not configured; email to %s not sent.\nSubject: %s\n%s",
            to, subject, text,
        )
        return False

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
    except Exception:
        logger.exception("Failed to send email to %s", to)
        return False
