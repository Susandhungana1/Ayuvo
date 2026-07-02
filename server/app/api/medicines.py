from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.config import get_session
from app.models.models import User, Medicine

router = APIRouter()


class MedicineCreate(BaseModel):
    name: str
    dosage: str
    frequency: str
    start_date: str
    end_date: Optional[str] = None
    notes: Optional[str] = None


class MedicineUpdate(BaseModel):
    name: Optional[str] = None
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    notes: Optional[str] = None


class MedicineResponse(BaseModel):
    id: str
    name: str
    dosage: str
    frequency: str
    start_date: str
    end_date: Optional[str]
    notes: Optional[str]
    created_at: Optional[str]


class MedicinesListResponse(BaseModel):
    medicines: List[MedicineResponse]


@router.get("", response_model=MedicinesListResponse)
async def list_medicines(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    medicines = db.exec(
        select(Medicine)
        .where(Medicine.user_id == current_user.id)
        .order_by(Medicine.created_at.desc())
    ).all()

    return MedicinesListResponse(
        medicines=[
            MedicineResponse(
                id=m.id,
                name=m.name,
                dosage=m.dosage,
                frequency=m.frequency,
                start_date=m.start_date,
                end_date=m.end_date,
                notes=m.notes,
                created_at=str(m.created_at) if m.created_at else None
            )
            for m in medicines
        ]
    )


@router.post("", response_model=MedicineResponse)
async def create_medicine(
    data: MedicineCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    medicine = Medicine(
        user_id=current_user.id,
        name=data.name,
        dosage=data.dosage,
        frequency=data.frequency,
        start_date=data.start_date,
        end_date=data.end_date,
        notes=data.notes
    )
    db.add(medicine)
    db.commit()
    db.refresh(medicine)
    return MedicineResponse(
        id=medicine.id,
        name=medicine.name,
        dosage=medicine.dosage,
        frequency=medicine.frequency,
        start_date=medicine.start_date,
        end_date=medicine.end_date,
        notes=medicine.notes,
        created_at=str(medicine.created_at) if medicine.created_at else None
    )


@router.put("/{medicine_id}", response_model=MedicineResponse)
async def update_medicine(
    medicine_id: str,
    data: MedicineUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    medicine = db.get(Medicine, medicine_id)
    if not medicine or medicine.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Medicine not found")

    if data.name is not None:
        medicine.name = data.name
    if data.dosage is not None:
        medicine.dosage = data.dosage
    if data.frequency is not None:
        medicine.frequency = data.frequency
    if data.start_date is not None:
        medicine.start_date = data.start_date
    if data.end_date is not None:
        medicine.end_date = data.end_date
    if data.notes is not None:
        medicine.notes = data.notes

    db.add(medicine)
    db.commit()
    db.refresh(medicine)
    return MedicineResponse(
        id=medicine.id,
        name=medicine.name,
        dosage=medicine.dosage,
        frequency=medicine.frequency,
        start_date=medicine.start_date,
        end_date=medicine.end_date,
        notes=medicine.notes,
        created_at=str(medicine.created_at) if medicine.created_at else None
    )


@router.delete("/{medicine_id}")
async def delete_medicine(
    medicine_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    medicine = db.get(Medicine, medicine_id)
    if not medicine or medicine.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Medicine not found")

    db.delete(medicine)
    db.commit()
    return {"message": "Medicine deleted"}
