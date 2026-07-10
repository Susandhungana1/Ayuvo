"""Web Push delivery helper (VAPID).

Thin wrapper around pywebpush so the rest of the app doesn't import it directly.
Degrades gracefully: if pywebpush isn't installed or VAPID keys aren't set,
`send_push` is a no-op that reports "not sent" instead of raising.
"""

import json
from typing import Optional

from app.core.config import settings

try:  # pywebpush is optional; push simply stays disabled without it.
    from pywebpush import webpush, WebPushException  # type: ignore

    _HAVE_PYWEBPUSH = True
except Exception:  # pragma: no cover - import guard
    webpush = None  # type: ignore
    WebPushException = Exception  # type: ignore
    _HAVE_PYWEBPUSH = False


def push_available() -> bool:
    return _HAVE_PYWEBPUSH and settings.push_enabled


class PushResult:
    def __init__(self, ok: bool, gone: bool = False, error: Optional[str] = None):
        self.ok = ok
        self.gone = gone  # 404/410 → subscription is dead, caller should delete it
        self.error = error


def send_push(endpoint: str, p256dh: str, auth: str, payload: dict) -> PushResult:
    """Send one push. Never raises; returns a PushResult the caller can act on."""
    if not push_available():
        return PushResult(ok=False, error="push disabled")

    subscription_info = {
        "endpoint": endpoint,
        "keys": {"p256dh": p256dh, "auth": auth},
    }
    try:
        webpush(
            subscription_info=subscription_info,
            data=json.dumps(payload),
            vapid_private_key=settings.vapid_private_key,
            vapid_claims={"sub": settings.vapid_subject},
            ttl=120,  # a stale medicine alarm is worse than none — expire fast
        )
        return PushResult(ok=True)
    except WebPushException as exc:  # type: ignore
        status = getattr(getattr(exc, "response", None), "status_code", None)
        gone = status in (404, 410)
        return PushResult(ok=False, gone=gone, error=str(exc))
    except Exception as exc:  # pragma: no cover - defensive
        return PushResult(ok=False, error=str(exc))
