from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel
from sqlmodel import Session, select, or_

from app.api.auth import get_current_user
from app.core.config import get_session
from app.core.ratelimit import limiter
from app.models.models import User, MedicalReport, Medicine, MedicalDocument

router = APIRouter()


class SearchResultItem(BaseModel):
    type: str
    id: str
    title: str
    snippet: Optional[str]
    date: Optional[str]


class SearchResponse(BaseModel):
    query: str
    results: List[SearchResultItem]
    total: int


@router.get("", response_model=SearchResponse)
@limiter.limit("60/hour")
async def search(
    request: Request,
    q: str = Query(default="", min_length=1),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    query = q.strip()
    if not query:
        return SearchResponse(query=query, results=[], total=0)

    pattern = f"%{query}%"
    results: list[SearchResultItem] = []
    seen: set[str] = set()

    # --- Reports: search type, notes, extracted_text, file_name ---
    report_rows = db.exec(
        select(MedicalReport)
        .where(MedicalReport.user_id == current_user.id)
        .where(
            or_(
                MedicalReport.report_type.ilike(pattern),
                MedicalReport.notes.ilike(pattern),
                MedicalReport.extracted_text.ilike(pattern),
                MedicalReport.file_name.ilike(pattern),
            )
        )
        .order_by(MedicalReport.created_at.desc())
    ).all()

    for r in report_rows:
        if r.id in seen:
            continue
        seen.add(r.id)
        snippet = r.notes or r.extracted_text or ""
        results.append(SearchResultItem(
            type="report",
            id=r.id,
            title=f"{r.file_name} ({r.report_type.value if hasattr(r.report_type, 'value') else r.report_type})",
            snippet=snippet[:200] if snippet else None,
            date=str(r.created_at) if r.created_at else None,
        ))

    # --- Medicines: search name, dosage, frequency, notes ---
    medicine_rows = db.exec(
        select(Medicine)
        .where(Medicine.user_id == current_user.id)
        .where(Medicine.deleted_at.is_(None))
        .where(
            or_(
                Medicine.name.ilike(pattern),
                Medicine.dosage.ilike(pattern),
                Medicine.frequency.ilike(pattern),
                Medicine.notes.ilike(pattern),
            )
        )
        .order_by(Medicine.created_at.desc())
    ).all()

    for m in medicine_rows:
        if m.id in seen:
            continue
        seen.add(m.id)
        results.append(SearchResultItem(
            type="medicine",
            id=m.id,
            title=m.name,
            snippet=f"{m.dosage} - {m.frequency}",
            date=str(m.created_at) if m.created_at else None,
        ))

    # --- Documents: search hospital, doctor_name, department, description, location ---
    doc_rows = db.exec(
        select(MedicalDocument)
        .where(MedicalDocument.user_id == current_user.id)
        .where(MedicalDocument.deleted_at.is_(None))
        .where(
            or_(
                MedicalDocument.hospital.ilike(pattern),
                MedicalDocument.doctor_name.ilike(pattern),
                MedicalDocument.department.ilike(pattern),
                MedicalDocument.description.ilike(pattern),
                MedicalDocument.location.ilike(pattern),
            )
        )
        .order_by(MedicalDocument.created_at.desc())
    ).all()

    for d in doc_rows:
        if d.id in seen:
            continue
        seen.add(d.id)
        snippet = d.description or f"{d.hospital} - {d.doctor_name or ''}"
        results.append(SearchResultItem(
            type="document",
            id=d.id,
            title=f"Document - {d.hospital}",
            snippet=snippet[:200] if snippet else None,
            date=str(d.created_at) if d.created_at else None,
        ))

    total = len(results)
    results = results[offset:offset + limit]
    return SearchResponse(query=query, results=results, total=total)
