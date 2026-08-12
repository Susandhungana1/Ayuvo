from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, field_validator
from sqlmodel import Session, select

from app.api.auth import get_current_user, get_session
from app.models.models import User

router = APIRouter()


class UserUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    # IANA timezone (e.g. "Asia/Kathmandu"), sent by the mobile app at sign-in.
    # Optional and unset by default; an empty string means "unset".
    timezone: Optional[str] = None

    @field_validator("timezone")
    @classmethod
    def _blank_timezone_is_none(cls, v: Optional[str]) -> Optional[str]:
        return v.strip() if isinstance(v, str) and v.strip() else None


class UserDetail(BaseModel):
    id: str
    name: str
    email: str
    role: str
    address: Optional[str] = None
    city: Optional[str] = None
    timezone: Optional[str] = None


@router.get("/me", response_model=UserDetail)
async def get_current_user_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    return UserDetail(
        id=current_user.id,
        name=current_user.name,
        email=current_user.email,
        role=current_user.role,
        address=current_user.address,
        city=current_user.city,
        timezone=current_user.timezone
    )


@router.put("/me", response_model=UserDetail)
async def update_current_user(
    user_data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    if user_data.name:
        current_user.name = user_data.name
    if user_data.address:
        current_user.address = user_data.address
    if user_data.city:
        current_user.city = user_data.city
    if user_data.latitude is not None:
        current_user.latitude = user_data.latitude
    if user_data.longitude is not None:
        current_user.longitude = user_data.longitude
    if "timezone" in user_data.model_fields_set:
        current_user.timezone = user_data.timezone

    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    
    return UserDetail(
        id=current_user.id,
        name=current_user.name,
        email=current_user.email,
        role=current_user.role,
        address=current_user.address,
        city=current_user.city,
        timezone=current_user.timezone
    )