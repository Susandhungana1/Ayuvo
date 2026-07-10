"""Web Push subscription management for medicine reminders."""

from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.config import get_session, settings
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
