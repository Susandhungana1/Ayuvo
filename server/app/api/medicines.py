from datetime import datetime
from typing import Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.care import resolve_medicine_scope, utc_iso
from app.core.config import get_session
from app.core.drug_interactions import check_interactions
from app.models.models import User, Medicine, MedicineAudit, MedicineIntakeLog

router = APIRouter()

# Every endpoint below takes an optional `patient_id`. Omitted means "my own
# medicines", so every pre-caretaker caller behaves exactly as before. When
# supplied it is resolved through resolve_medicine_scope, which is the only
# thing permitted to decide whether one account may touch another's list.
#
# It is read from the query string only. A body-supplied patient_id would let a
# caretaker aim a write at an arbitrary account, so the request models below
# deliberately have no such field.
PatientScope = Optional[str]


def _snapshot(med: Medicine) -> dict[str, Any]:
    """The audit-visible shape of a medicine row."""
    return {
        "id": med.id,
        "name": med.name,
        "dosage": med.dosage,
        "frequency": med.frequency,
        "start_date": med.start_date,
        "end_date": med.end_date,
        "taking_times": med.taking_times,
        "notes": med.notes,
    }


def _record_change(
    db: Session,
    *,
    patient_id: str,
    actor_id: str,
    medicine_id: Optional[str],
    action: str,
    before: Optional[dict] = None,
    after: Optional[dict] = None,
) -> None:
    """Append a medicine-audit row so the patient can see caretaker activity."""
    db.add(
        MedicineAudit(
            patient_id=patient_id,
            actor_id=actor_id,
            medicine_id=medicine_id,
            action=action,
            before=before,
            after=after,
        )
    )


def _announce(
    db: Session, patient_id: str, actor: User, action: str, medicine_name: str
) -> None:
    """Let the patient know a caretaker touched their list. No-op when the
    patient is the one acting."""
    if actor.id == patient_id:
        return
    patient = db.get(User, patient_id)
    if patient is None:
        return

    from app.core.notify import notify_medicine_change

    notify_medicine_change(
        db, patient=patient, actor=actor, action=action, medicine_name=medicine_name
    )


def _owned_medicine(db: Session, medicine_id: str, scope: str) -> Medicine:
    """Fetch a medicine, insisting it belongs to the resolved scope.

    Checking ownership *after* scope resolution is what stops a caretaker from
    pairing their own client's patient_id with a stranger's medicine_id: the
    link check passes, but the row's owner doesn't match the scope it was
    fetched under. 404 rather than 403 so the response can't confirm that some
    other account holds that id.
    """
    med = db.get(Medicine, medicine_id)
    if not med or med.user_id != scope or med.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Medicine not found")
    return med


class MedicineCreate(BaseModel):
    name: str
    dosage: str
    frequency: str
    start_date: str
    end_date: Optional[str] = None
    taking_times: Optional[str] = None
    notes: Optional[str] = None


class MedicineUpdate(BaseModel):
    name: Optional[str] = None
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    taking_times: Optional[str] = None
    notes: Optional[str] = None


class MedicineResponse(BaseModel):
    id: str
    name: str
    dosage: str
    frequency: str
    start_date: str
    end_date: Optional[str]
    taking_times: Optional[str] = None
    notes: Optional[str]
    created_at: Optional[str]


class MedicinesListResponse(BaseModel):
    medicines: List[MedicineResponse]


@router.get("", response_model=MedicinesListResponse)
async def list_medicines(
    patient_id: PatientScope = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    scope = resolve_medicine_scope(db, actor_id=current_user.id, patient_id=patient_id)
    medicines = db.exec(
        select(Medicine)
        .where(
            Medicine.user_id == scope,
            Medicine.deleted_at.is_(None),  # type: ignore[union-attr]
        )
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
                taking_times=m.taking_times,
                notes=m.notes,
                created_at=str(m.created_at) if m.created_at else None
            )
            for m in medicines
        ]
    )


class InteractionItem(BaseModel):
    drug_a: str
    drug_b: str
    severity: str
    description: str


class InteractionsResponse(BaseModel):
    interactions: List[InteractionItem]
    checked_count: int


@router.get("/interactions", response_model=InteractionsResponse)
async def get_medicine_interactions(
    patient_id: PatientScope = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    """Check the user's current medicines for known interactions (offline dataset).

    Scoped like the list itself: this is derived purely from the medicines a
    caretaker can already see, so it exposes nothing further.
    """
    scope = resolve_medicine_scope(db, actor_id=current_user.id, patient_id=patient_id)
    today = datetime.utcnow().date().isoformat()
    medicines = db.exec(
        select(Medicine).where(
            Medicine.user_id == scope,
            Medicine.deleted_at.is_(None),  # type: ignore[union-attr]
        )
    ).all()
    # Only consider active medicines (not ended).
    active = [m for m in medicines if not m.end_date or m.end_date >= today]
    names = [m.name for m in active]
    interactions = check_interactions(names)
    return InteractionsResponse(
        interactions=[InteractionItem(**i) for i in interactions],
        checked_count=len(names),
    )


class IntakeCreate(BaseModel):
    scheduled_time: str
    status: str = "taken"  # taken | snoozed | skipped


class IntakeItem(BaseModel):
    id: str
    medicine_id: str
    scheduled_time: str
    status: str
    recorded_at: str


class IntakeLogResponse(BaseModel):
    intakes: List[IntakeItem]


_ALLOWED_INTAKE_STATUS = {"taken", "snoozed", "skipped"}


@router.post("/{medicine_id}/intake", response_model=IntakeItem)
async def record_intake(
    medicine_id: str,
    data: IntakeCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    """Record that a scheduled dose was taken / snoozed / skipped (adherence log).

    Deliberately self-only, with no patient_id: a caretaker manages the
    medicine *list*, but whether a dose was actually swallowed is the patient's
    own account of it and must not be assertable on their behalf.
    """
    medicine = db.get(Medicine, medicine_id)
    if not medicine or medicine.user_id != current_user.id or medicine.deleted_at:
        raise HTTPException(status_code=404, detail="Medicine not found")

    status = data.status if data.status in _ALLOWED_INTAKE_STATUS else "taken"
    log = MedicineIntakeLog(
        user_id=current_user.id,
        medicine_id=medicine_id,
        scheduled_time=data.scheduled_time,
        status=status,
    )
    db.add(log)
    db.commit()
    db.refresh(log)
    return IntakeItem(
        id=log.id,
        medicine_id=log.medicine_id,
        scheduled_time=log.scheduled_time,
        status=log.status,
        recorded_at=str(log.recorded_at),
    )


@router.get("/intake/log", response_model=IntakeLogResponse)
async def list_intake_log(
    limit: int = 100,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    """Recent adherence history for the current user, newest first."""
    limit = max(1, min(limit, 500))
    logs = db.exec(
        select(MedicineIntakeLog)
        .where(MedicineIntakeLog.user_id == current_user.id)
        .order_by(MedicineIntakeLog.recorded_at.desc())
        .limit(limit)
    ).all()
    return IntakeLogResponse(
        intakes=[
            IntakeItem(
                id=log.id,
                medicine_id=log.medicine_id,
                scheduled_time=log.scheduled_time,
                status=log.status,
                recorded_at=str(log.recorded_at),
            )
            for log in logs
        ]
    )


@router.post("", response_model=MedicineResponse)
async def create_medicine(
    data: MedicineCreate,
    patient_id: PatientScope = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    scope = resolve_medicine_scope(db, actor_id=current_user.id, patient_id=patient_id)
    # The owner is always the resolved scope. Caretakers never own medicine rows.
    medicine = Medicine(
        user_id=scope,
        name=data.name,
        dosage=data.dosage,
        frequency=data.frequency,
        start_date=data.start_date,
        end_date=data.end_date,
        taking_times=data.taking_times,
        notes=data.notes
    )
    db.add(medicine)
    db.commit()
    db.refresh(medicine)

    _record_change(
        db,
        patient_id=scope,
        actor_id=current_user.id,
        medicine_id=medicine.id,
        action="create",
        after=_snapshot(medicine),
    )
    db.commit()
    _announce(db, scope, current_user, "create", medicine.name)

    return MedicineResponse(
        id=medicine.id,
        name=medicine.name,
        dosage=medicine.dosage,
        frequency=medicine.frequency,
        start_date=medicine.start_date,
        end_date=medicine.end_date,
        taking_times=medicine.taking_times,
        notes=medicine.notes,
        created_at=str(medicine.created_at) if medicine.created_at else None
    )


@router.put("/{medicine_id}", response_model=MedicineResponse)
async def update_medicine(
    medicine_id: str,
    data: MedicineUpdate,
    patient_id: PatientScope = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    scope = resolve_medicine_scope(db, actor_id=current_user.id, patient_id=patient_id)
    medicine = _owned_medicine(db, medicine_id, scope)
    before = _snapshot(medicine)

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
    if data.taking_times is not None:
        medicine.taking_times = data.taking_times

    db.add(medicine)
    db.commit()
    db.refresh(medicine)

    _record_change(
        db,
        patient_id=scope,
        actor_id=current_user.id,
        medicine_id=medicine.id,
        action="update",
        before=before,
        after=_snapshot(medicine),
    )
    db.commit()

    return MedicineResponse(
        id=medicine.id,
        name=medicine.name,
        dosage=medicine.dosage,
        frequency=medicine.frequency,
        start_date=medicine.start_date,
        end_date=medicine.end_date,
        taking_times=medicine.taking_times,
        notes=medicine.notes,
        created_at=str(medicine.created_at) if medicine.created_at else None
    )


@router.delete("/{medicine_id}")
async def delete_medicine(
    medicine_id: str,
    patient_id: PatientScope = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    """Soft delete. The row is retired, not dropped, so a patient can restore a
    medicine a caretaker removed — and so the audit trail keeps its subject."""
    scope = resolve_medicine_scope(db, actor_id=current_user.id, patient_id=patient_id)
    medicine = _owned_medicine(db, medicine_id, scope)
    before = _snapshot(medicine)

    medicine.deleted_at = datetime.utcnow()
    db.add(medicine)
    db.commit()

    _record_change(
        db,
        patient_id=scope,
        actor_id=current_user.id,
        medicine_id=medicine.id,
        action="delete",
        before=before,
    )
    db.commit()
    _announce(db, scope, current_user, "delete", medicine.name)

    return {"message": "Medicine deleted"}


@router.post("/{medicine_id}/restore", response_model=MedicineResponse)
async def restore_medicine(
    medicine_id: str,
    patient_id: PatientScope = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    """Undo a soft delete — the action offered beside a removal in the patient's
    caretaker-activity feed."""
    scope = resolve_medicine_scope(db, actor_id=current_user.id, patient_id=patient_id)

    medicine = db.get(Medicine, medicine_id)
    if not medicine or medicine.user_id != scope:
        raise HTTPException(status_code=404, detail="Medicine not found")
    if medicine.deleted_at is None:
        raise HTTPException(status_code=400, detail="That medicine isn't deleted")

    medicine.deleted_at = None
    db.add(medicine)
    db.commit()
    db.refresh(medicine)

    _record_change(
        db,
        patient_id=scope,
        actor_id=current_user.id,
        medicine_id=medicine.id,
        action="restore",
        after=_snapshot(medicine),
    )
    db.commit()

    return MedicineResponse(
        id=medicine.id,
        name=medicine.name,
        dosage=medicine.dosage,
        frequency=medicine.frequency,
        start_date=medicine.start_date,
        end_date=medicine.end_date,
        taking_times=medicine.taking_times,
        notes=medicine.notes,
        created_at=str(medicine.created_at) if medicine.created_at else None
    )


class AuditItem(BaseModel):
    id: int
    actor_id: str
    actor_name: str
    medicine_id: Optional[str]
    medicine_name: Optional[str]
    action: str
    created_at: str
    by_caretaker: bool


class AuditListResponse(BaseModel):
    entries: List[AuditItem]


@router.get("/audit", response_model=AuditListResponse)
async def list_medicine_audit(
    patient_id: PatientScope = Query(default=None),
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    """Medicine change history.

    A patient sees every change to their own list. A caretaker sees only the
    changes they themselves made — one caretaker has no business reviewing
    another's activity on the same patient.
    """
    scope = resolve_medicine_scope(db, actor_id=current_user.id, patient_id=patient_id)
    limit = max(1, min(limit, 200))

    query = select(MedicineAudit).where(MedicineAudit.patient_id == scope)
    if current_user.id != scope:
        query = query.where(MedicineAudit.actor_id == current_user.id)

    rows = db.exec(
        query.order_by(MedicineAudit.created_at.desc()).limit(limit)  # type: ignore[union-attr]
    ).all()

    entries: List[AuditItem] = []
    for row in rows:
        actor = db.get(User, row.actor_id)
        snapshot = row.after or row.before or {}
        entries.append(
            AuditItem(
                id=row.id,
                actor_id=row.actor_id,
                actor_name=actor.name if actor else "Unknown",
                medicine_id=row.medicine_id,
                medicine_name=snapshot.get("name"),
                action=row.action,
                created_at=utc_iso(row.created_at),
                by_caretaker=row.actor_id != scope,
            )
        )
    return AuditListResponse(entries=entries)
