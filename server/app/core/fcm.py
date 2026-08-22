"""Firebase Cloud Messaging delivery helper.

Thin wrapper around firebase-admin so the rest of the app doesn't import it
directly.  Degrades gracefully: if firebase-admin isn't installed or the
service-account key is missing, FCM push is a no-op that logs and moves on.

Credentials are loaded in order:
  1. FIREBASE_CREDENTIALS env var (JSON string) — best for containers/Render.
  2. FIREBASE_SERVICE_ACCOUNT_PATH file path — fine for local dev.
"""

import json
import logging
import os
from pathlib import Path
from typing import Optional

from app.core.config import settings

logger = logging.getLogger("fcm")

try:
    import firebase_admin  # type: ignore
    from firebase_admin import credentials, messaging  # type: ignore

    _initialized = False

    # 1) Try the env var first (JSON string — no file needed in Docker).
    _creds_json = os.environ.get("FIREBASE_CREDENTIALS", "")
    if _creds_json:
        try:
            _info = json.loads(_creds_json)
            _cred = credentials.Certificate(_info)
            firebase_admin.initialize_app(_cred)
            _initialized = True
            logger.info("Firebase Admin initialized from FIREBASE_CREDENTIALS env var")
        except Exception as exc:
            logger.warning("Failed to parse FIREBASE_CREDENTIALS: %s", exc)

    # 2) Fall back to the file path.
    if not _initialized:
        _service_account_path = Path(settings.firebase_service_account_path)
        if _service_account_path.exists():
            _cred = credentials.Certificate(str(_service_account_path))
            firebase_admin.initialize_app(_cred)
            _initialized = True
            logger.info("Firebase Admin initialized from %s", _service_account_path)

    _FCM_ENABLED = _initialized
    if not _initialized:
        logger.info("No Firebase credentials found — FCM push disabled")

except Exception:
    _FCM_ENABLED = False
    logger.info("firebase-admin not installed — FCM push disabled")


def fcm_available() -> bool:
    return _FCM_ENABLED


class FcmResult:
    def __init__(self, ok: bool, invalid_token: bool = False, error: Optional[str] = None):
        self.ok = ok
        self.invalid_token = invalid_token
        self.error = error


def send_fcm(token: str, payload: dict) -> FcmResult:
    """Send one FCM push. Never raises; returns an FcmResult."""
    if not _FCM_ENABLED:
        return FcmResult(ok=False, error="FCM not configured")

    title = payload.get("title", "Medicine Reminder")
    body = payload.get("body", "")

    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in payload.items() if v is not None},
        token=token,
    )

    try:
        messaging.send(message)
        return FcmResult(ok=True)
    except messaging.UnregisteredError:
        return FcmResult(ok=False, invalid_token=True, error="token unregistered")
    except messaging.SenderIdMismatchError:
        return FcmResult(ok=False, invalid_token=True, error="sender mismatch")
    except Exception as exc:
        return FcmResult(ok=False, error=str(exc)[:200])
