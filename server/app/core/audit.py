"""Access & audit logging.

Central helper so every sensitive-access site logs the same shape of event.
Writes are best-effort: an audit-log failure must never break the user request,
but it is reported to Sentry (if configured) so we notice a broken audit trail.
"""

from __future__ import annotations

from typing import Optional

from fastapi import Request
from sqlmodel import Session

from app.models.models import AuditLog


def _client_ip(request: Optional[Request]) -> Optional[str]:
    if request is None:
        return None
    # Honour the first X-Forwarded-For hop when behind a reverse proxy / load
    # balancer, else fall back to the socket peer.
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else None


def record_access(
    db: Session,
    action: str,
    *,
    actor_id: Optional[str] = None,
    subject_id: Optional[str] = None,
    resource_type: Optional[str] = None,
    resource_id: Optional[str] = None,
    request: Optional[Request] = None,
    detail: Optional[str] = None,
) -> None:
    """Append one audit event. Never raises into the caller."""
    try:
        entry = AuditLog(
            actor_id=actor_id,
            subject_id=subject_id,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            ip_address=_client_ip(request),
            user_agent=(request.headers.get("user-agent") if request else None),
            detail=detail,
        )
        db.add(entry)
        db.commit()
    except Exception:  # pragma: no cover - defensive; audit must not break requests
        try:
            db.rollback()
        except Exception:
            pass
        try:
            import sentry_sdk

            sentry_sdk.capture_message("audit-log write failed", level="error")
        except Exception:
            pass