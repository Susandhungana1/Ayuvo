from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.config import get_session
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
async def search(
    q: str = Query(default="", min_length=1),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    query = q.strip()
    if not query:
        return SearchResponse(query=query, results=[], total=0)

    results = []
    seen = set()

    query_lower = query.lower()

    reports = db.exec(
        select(MedicalReport)
        .where(MedicalReport.user_id == current_user.id)
        .order_by(MedicalReport.created_at.desc())
    ).all()

    for report in reports:
        if report.id in seen:
            continue
        searchable = " ".join(filter(None, [
            report.report_type.value if hasattr(report.report_type, 'value') else str(report.report_type),
            report.notes or "",
            report.result_summary or "",
            report.extracted_text or "",
            report.file_name or "",
        ])).lower()
        if query_lower in searchable:
            seen.add(report.id)
            snippet = report.result_summary or report.notes or report.extracted_text or ""
            snippet = snippet[:200] if snippet else ""
            results.append(SearchResultItem(
                type="report",
                id=report.id,
                title=f"{report.file_name} ({report.report_type.value if hasattr(report.report_type, 'value') else report.report_type})",
                snippet=snippet,
                date=str(report.created_at) if report.created_at else None,
            ))

    medicines = db.exec(
        select(Medicine)
        .where(Medicine.user_id == current_user.id)
        .order_by(Medicine.created_at.desc())
    ).all()

    for medicine in medicines:
        if medicine.id in seen:
            continue
        searchable = " ".join(filter(None, [
            medicine.name,
            medicine.dosage,
            medicine.frequency,
            medicine.notes or "",
        ])).lower()
        if query_lower in searchable:
            seen.add(medicine.id)
            results.append(SearchResultItem(
                type="medicine",
                id=medicine.id,
                title=medicine.name,
                snippet=f"{medicine.dosage} - {medicine.frequency}",
                date=str(medicine.created_at) if medicine.created_at else None,
            ))

    documents = db.exec(
        select(MedicalDocument)
        .where(MedicalDocument.user_id == current_user.id)
        .where(MedicalDocument.deleted_at.is_(None))
        .order_by(MedicalDocument.created_at.desc())
    ).all()

    for doc in documents:
        if doc.id in seen:
            continue
        searchable = " ".join(filter(None, [
            doc.hospital or "",
            doc.doctor_name or "",
            doc.department or "",
            doc.description or "",
            doc.location or "",
        ])).lower()
        if query_lower in searchable:
            seen.add(doc.id)
            snippet = doc.description or f"{doc.hospital} - {doc.doctor_name or ''}"
            snippet = snippet[:200] if snippet else ""
            results.append(SearchResultItem(
                type="document",
                id=doc.id,
                title=f"Document - {doc.hospital}",
                snippet=snippet,
                date=str(doc.created_at) if doc.created_at else None,
            ))

    return SearchResponse(query=query, results=results, total=len(results))
