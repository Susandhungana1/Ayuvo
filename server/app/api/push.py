"""Web Push subscription management for medicine reminders."""

from typing import Optional
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

import asyncio

from app.api.auth import get_current_user
from app.core.config import get_session, settings
from app.core.reminder_scheduler import run_tick_once
from app.core.webpush import send_push
from app.models.models import User, PushSubscription

router = APIRouter()


class SubscriptionKeys(BaseModel):
    p256dh: str
    auth: str


class SubscribeRequest(BaseModel):
    endpoint: str
    keys: SubscriptionKeys
    timezone: Optional[str] = "UTC"


class UnsubscribeRequest(BaseModel):
    endpoint: str


class VapidKeyResponse(BaseModel):
    public_key: str
    enabled: bool


@router.get("/vapid-public-key", response_model=VapidKeyResponse)
async def get_vapid_public_key():
    """Public VAPID key the browser needs to create a push subscription."""
    return VapidKeyResponse(
        public_key=settings.vapid_public_key,
        enabled=settings.push_enabled,
    )


@router.post("/subscribe")
async def subscribe(
    data: SubscribeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Register (or refresh) this device's push subscription for the user."""
    if not settings.push_enabled:
        raise HTTPException(status_code=503, detail="Push notifications are not configured")

    existing = db.exec(
        select(PushSubscription).where(PushSubscription.endpoint == data.endpoint)
    ).first()

    if existing:
        # Re-point the endpoint at the current user + refresh keys/timezone.
        existing.user_id = current_user.id
        existing.p256dh = data.keys.p256dh
        existing.auth = data.keys.auth
        existing.timezone = data.timezone or "UTC"
        db.add(existing)
    else:
        db.add(
            PushSubscription(
                user_id=current_user.id,
                endpoint=data.endpoint,
                p256dh=data.keys.p256dh,
                auth=data.keys.auth,
                timezone=data.timezone or "UTC",
            )
        )
    db.commit()
    return {"message": "subscribed"}


@router.post("/test")
async def test_push(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Send a test reminder to all of the current user's devices right now.

    Returns how many subscriptions exist and how many pushes actually went out —
    lets a user verify end-to-end delivery without waiting for a clock time, and
    tells us whether a failure is registration (subscriptions=0) or delivery."""
    if not settings.push_enabled:
        raise HTTPException(status_code=503, detail="Push notifications are not configured")

    subs = db.exec(
        select(PushSubscription).where(PushSubscription.user_id == current_user.id)
    ).all()

    payload = {
        "title": "✅ Test reminder",
        "body": "Your medicine reminders are working.",
        "tag": "medicine-test",
    }

    sent = 0
    dead: list[PushSubscription] = []
    for sub in subs:
        result = await asyncio.to_thread(send_push, sub.endpoint, sub.p256dh, sub.auth, payload)
        if result.ok:
            sent += 1
        elif result.gone:
            dead.append(sub)

    for sub in dead:
        db.delete(sub)
    if dead:
        db.commit()

    return {"subscriptions": len(subs), "sent": sent, "removed": len(dead)}


@router.post("/run-tick")
async def run_tick(x_cron_secret: str = Header(default="")):
    """Deliver any reminders due right now. Meant to be called every minute by an
    external scheduler on hosts that sleep. Guarded by CRON_SECRET; disabled
    (404) when the secret is unset so it is never publicly triggerable."""
    if not settings.cron_secret or x_cron_secret != settings.cron_secret:
        raise HTTPException(status_code=404, detail="Not found")
    sent = await run_tick_once()
    return {"ok": True, "sent": sent}


@router.post("/unsubscribe")
async def unsubscribe(
    data: UnsubscribeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    sub = db.exec(
        select(PushSubscription).where(PushSubscription.endpoint == data.endpoint)
    ).first()
    if sub and sub.user_id == current_user.id:
        db.delete(sub)
        db.commit()
    return {"message": "unsubscribed"}
