from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.config import get_session
from app.core.time import utcnow
from app.models.models import User, VitalSign

router = APIRouter()


class VitalSignCreate(BaseModel):
    blood_pressure_systolic: Optional[int] = None
    blood_pressure_diastolic: Optional[int] = None
    heart_rate: Optional[int] = None
    weight: Optional[float] = None
    blood_sugar: Optional[float] = None
    temperature: Optional[float] = None
    oxygen_saturation: Optional[int] = None
    notes: Optional[str] = None
    measured_at: Optional[datetime] = None


class VitalSignResponse(BaseModel):
    id: str
    blood_pressure_systolic: Optional[int]
    blood_pressure_diastolic: Optional[int]
    heart_rate: Optional[int]
    weight: Optional[float]
    blood_sugar: Optional[float]
    temperature: Optional[float]
    oxygen_saturation: Optional[int]
    notes: Optional[str]
    measured_at: str
    created_at: str


class VitalSignsListResponse(BaseModel):
    vitals: List[VitalSignResponse]


@router.get("", response_model=VitalSignsListResponse)
async def list_vitals(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
):
    vitals = db.exec(
        select(VitalSign)
        .where(VitalSign.user_id == current_user.id)
        .order_by(VitalSign.measured_at.desc())
        .offset(offset)
        .limit(limit)
    ).all()

    return VitalSignsListResponse(
        vitals=[
            VitalSignResponse(
                id=v.id,
                blood_pressure_systolic=v.blood_pressure_systolic,
                blood_pressure_diastolic=v.blood_pressure_diastolic,
                heart_rate=v.heart_rate,
                weight=v.weight,
                blood_sugar=v.blood_sugar,
                temperature=v.temperature,
                oxygen_saturation=v.oxygen_saturation,
                notes=v.notes,
                measured_at=str(v.measured_at),
                created_at=str(v.created_at),
            )
            for v in vitals
        ]
    )


@router.post("", response_model=VitalSignResponse)
async def create_vital(
    data: VitalSignCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    vital = VitalSign(
        user_id=current_user.id,
        blood_pressure_systolic=data.blood_pressure_systolic,
        blood_pressure_diastolic=data.blood_pressure_diastolic,
        heart_rate=data.heart_rate,
        weight=data.weight,
        blood_sugar=data.blood_sugar,
        temperature=data.temperature,
        oxygen_saturation=data.oxygen_saturation,
        notes=data.notes,
        measured_at=data.measured_at or utcnow(),
    )
    db.add(vital)
    db.commit()
    db.refresh(vital)
    return VitalSignResponse(
        id=vital.id,
        blood_pressure_systolic=vital.blood_pressure_systolic,
        blood_pressure_diastolic=vital.blood_pressure_diastolic,
        heart_rate=vital.heart_rate,
        weight=vital.weight,
        blood_sugar=vital.blood_sugar,
        temperature=vital.temperature,
        oxygen_saturation=vital.oxygen_saturation,
        notes=vital.notes,
        measured_at=str(vital.measured_at),
        created_at=str(vital.created_at),
    )


@router.delete("/{vital_id}")
async def delete_vital(
    vital_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    vital = db.get(VitalSign, vital_id)
    if not vital or vital.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Vital sign not found")
    db.delete(vital)
    db.commit()
    return {"message": "Vital sign deleted"}
