from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.config import get_session
from app.models.models import User, Dependent

router = APIRouter()


class DependentCreate(BaseModel):
    name: str
    relationship: str
    date_of_birth: Optional[str] = None
    blood_type: Optional[str] = None
    allergies: Optional[str] = None
    medical_conditions: Optional[str] = None
    notes: Optional[str] = None


class DependentUpdate(BaseModel):
    name: Optional[str] = None
    relationship: Optional[str] = None
    date_of_birth: Optional[str] = None
    blood_type: Optional[str] = None
    allergies: Optional[str] = None
    medical_conditions: Optional[str] = None
    notes: Optional[str] = None


class DependentResponse(BaseModel):
    id: str
    name: str
    relationship: str
    date_of_birth: Optional[str]
    blood_type: Optional[str]
    allergies: Optional[str]
    medical_conditions: Optional[str]
    notes: Optional[str]


class DependentsListResponse(BaseModel):
    dependents: List[DependentResponse]


def _to_response(d: Dependent) -> DependentResponse:
    return DependentResponse(
        id=d.id,
        name=d.name,
        relationship=d.relationship,
        date_of_birth=d.date_of_birth,
        blood_type=d.blood_type,
        allergies=d.allergies,
        medical_conditions=d.medical_conditions,
        notes=d.notes,
    )


@router.get("", response_model=DependentsListResponse)
async def list_dependents(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    rows = db.exec(
        select(Dependent)
        .where(Dependent.guardian_id == current_user.id)
        .order_by(Dependent.created_at.desc())
    ).all()
    return DependentsListResponse(dependents=[_to_response(d) for d in rows])


@router.post("", response_model=DependentResponse)
async def create_dependent(
    data: DependentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    dependent = Dependent(guardian_id=current_user.id, **data.model_dump())
    db.add(dependent)
    db.commit()
    db.refresh(dependent)
    return _to_response(dependent)


@router.put("/{dependent_id}", response_model=DependentResponse)
async def update_dependent(
    dependent_id: str,
    data: DependentUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    dependent = db.get(Dependent, dependent_id)
    if not dependent or dependent.guardian_id != current_user.id:
        raise HTTPException(status_code=404, detail="Dependent not found")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(dependent, field, value)
    dependent.updated_at = datetime.utcnow()

    db.add(dependent)
    db.commit()
    db.refresh(dependent)
    return _to_response(dependent)


@router.delete("/{dependent_id}")
async def delete_dependent(
    dependent_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    dependent = db.get(Dependent, dependent_id)
    if not dependent or dependent.guardian_id != current_user.id:
        raise HTTPException(status_code=404, detail="Dependent not found")
    db.delete(dependent)
    db.commit()
    return {"message": "Dependent removed"}
