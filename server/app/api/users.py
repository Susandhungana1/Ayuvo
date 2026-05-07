from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
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


class UserDetail(BaseModel):
    id: str
    name: str
    email: str
    role: str
    address: Optional[str] = None
    city: Optional[str] = None


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
        city=current_user.city
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
    
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    
    return UserDetail(
        id=current_user.id,
        name=current_user.name,
        email=current_user.email,
        role=current_user.role,
        address=current_user.address,
        city=current_user.city
    )