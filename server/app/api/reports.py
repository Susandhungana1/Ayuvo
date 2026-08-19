import uuid
import os
import asyncio
import json
from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, UploadFile, File, Form, Request
from pydantic import BaseModel, Field
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.config import get_session, settings, engine
from app.core import storage
from app.core.audit import record_access
from app.core.lab_analysis import (
    REFERENCE_RANGES, analyze_lab_text, apply_overrides, summarize_findings,
)
from app.core.ocr import extract_report_text
from app.models.models import User, MedicalReport, MedicalReportType, MedicalDocument

router = APIRouter()


def get_report_bytes(report: MedicalReport) -> Optional[bytes]:
    """Return a report's file bytes from object storage, falling back to the
    legacy inline blob for rows created before the storage migration."""
    if report.storage_key:
        try:
            return storage.read_file(report.storage_key)
        except FileNotFoundError:
            return None
    return report.file_content


class ReportCreate(BaseModel):
    report_type: MedicalReportType
    report_date: Optional[datetime] = None
    notes: Optional[str] = Field(default=None, max_length=2000)


class ReportResponse(BaseModel):
    id: str
    report_type: str
    report_date: Optional[datetime]
    file_name: str
    notes: Optional[str]
    extracted_text: Optional[str]
    ocr_status: Optional[str] = None
    document_id: Optional[str] = None
    doctor_name: Optional[str] = None
    hospital: Optional[str] = None


class ReportListResponse(BaseModel):
    reports: List[ReportResponse]


class LabFinding(BaseModel):
    name: str
    value: float
    unit: str
    status: str
    reference_range: str
    category: str


class LabAnalysisResponse(BaseModel):
    overall: str
    total: int
    abnormal_count: int
    findings: List[LabFinding]


class TrendSeries(BaseModel):
    name: str
    unit: str
    reference_range: str
    points: List[dict]
    first_value: float
    last_value: float
    change: float
    percent_change: Optional[float]
    direction: str
    latest_status: str


class TrendsResponse(BaseModel):
    series: List[TrendSeries]


def _build_report_response(report: MedicalReport, db: Session) -> ReportResponse:
    doctor_name = report.doctor_name
    hospital = report.hospital
    if not doctor_name and not hospital and report.document_id:
        doc = db.exec(select(MedicalDocument).where(MedicalDocument.id == report.document_id)).first()
        if doc:
            doctor_name = doc.doctor_name
            hospital = doc.hospital
    return ReportResponse(
        id=report.id,
        report_type=report.report_type,
        report_date=report.report_date,
        file_name=report.file_name,
        notes=report.notes,
        extracted_text=report.extracted_text,
        ocr_status=report.ocr_status,
        document_id=report.document_id,
        doctor_name=doctor_name,
        hospital=hospital
    )


def _extract_and_store(report_id: str, content: bytes, file_name: str) -> None:
    """Run OCR outside the request lifecycle and persist the result, so an
    upload never blocks on a multi-second Tesseract pass. Opens its own session
    because the request's transaction is already committed."""
    try:
        text = asyncio.run(extract_report_text(content, file_name))
    except Exception as e:  # noqa: BLE001 — best-effort, never fatal
        print(f"OCR background error: {e}")
        text = None
    try:
        with Session(engine) as db:
            report = db.get(MedicalReport, report_id)
            if report is None:
                return
            report.extracted_text = text
            report.ocr_status = "DONE" if text else "FAILED"
            db.add(report)
            db.commit()
    except Exception as e:  # noqa: BLE001
        print(f"OCR background store error: {e}")


MAX_FILE_SIZE = 10 * 1024 * 1024


@router.post("", response_model=ReportResponse)
async def create_report(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    report_type: str = Form(...),
    notes: Optional[str] = Form(None),
    report_date: Optional[str] = Form(None),
    hospital: Optional[str] = Form(None),
    doctor_name: Optional[str] = Form(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    content = await file.read()
    
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="File size exceeds 10MB limit")
    
    file_name = file.filename

    storage_key = storage.save_file(
        content, original_name=file_name, prefix="reports",
        content_type=file.content_type,
    )

    report = MedicalReport(
        user_id=current_user.id,
        report_type=report_type,
        report_date=datetime.fromisoformat(report_date) if report_date else None,
        file_name=file_name,
        storage_key=storage_key,
        file_content_type=file.content_type,
        notes=notes,
        hospital=hospital,
        doctor_name=doctor_name,
        ocr_status="PENDING",
    )
    db.add(report)
    db.commit()
    db.refresh(report)

    background_tasks.add_task(_extract_and_store, report.id, content, file_name)
    
    return _build_report_response(report, db)


@router.get("", response_model=ReportListResponse)
async def list_reports(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    reports = db.exec(
        select(MedicalReport)
        .where(MedicalReport.user_id == current_user.id)
        .order_by(MedicalReport.created_at.desc())
    ).all()
    
    return ReportListResponse(
        reports=[_build_report_response(r, db) for r in reports]
    )


@router.delete("/{report_id}", response_model=dict)
async def delete_report(
    report_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    report = db.get(MedicalReport, report_id)
    if not report or report.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Report not found")
    
    # Delete related share links
    from app.models.models import ShareLink
    share_links = db.exec(select(ShareLink).where(ShareLink.report_id == report_id)).all()
    for link in share_links:
        db.delete(link)

    storage.delete_file(report.storage_key)
    db.delete(report)
    db.commit()
    return {"message": "Report deleted"}


@router.get("/trends", response_model=TrendsResponse)
async def get_lab_trends(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    """Track how each lab value changes across a user's reports over time."""
    reports = db.exec(
        select(MedicalReport)
        .where(MedicalReport.user_id == current_user.id)
        .order_by(MedicalReport.created_at.asc())
    ).all()

    # test name -> list of {date, value, unit, status, reference_range}
    grouped: dict[str, list[dict]] = {}
    meta: dict[str, dict] = {}
    for r in reports:
        when = (r.report_date or r.created_at)
        findings = apply_overrides(analyze_lab_text(r.extracted_text), r.lab_overrides)
        for f in findings:
            grouped.setdefault(f["name"], []).append({
                "date": when.isoformat() if when else None,
                "value": f["value"],
                "status": f["status"],
            })
            meta[f["name"]] = {"unit": f["unit"], "reference_range": f["reference_range"]}

    series: list[TrendSeries] = []
    for name, points in grouped.items():
        if len(points) < 2:
            continue  # need at least two data points for a trend
        first_v = points[0]["value"]
        last_v = points[-1]["value"]
        change = round(last_v - first_v, 2)
        pct = round((change / first_v) * 100, 1) if first_v else None
        direction = "up" if change > 0 else ("down" if change < 0 else "flat")
        series.append(TrendSeries(
            name=name,
            unit=meta[name]["unit"],
            reference_range=meta[name]["reference_range"],
            points=points,
            first_value=first_v,
            last_value=last_v,
            change=change,
            percent_change=pct,
            direction=direction,
            latest_status=points[-1]["status"],
        ))

    series.sort(key=lambda s: 0 if s.latest_status != "NORMAL" else 1)
    return TrendsResponse(series=series)


@router.get("/{report_id}", response_model=ReportResponse)
async def get_report(
    report_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    report = db.get(MedicalReport, report_id)
    if not report or report.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Report not found")
    
    return _build_report_response(report, db)


@router.get("/{report_id}/file")
async def download_report_file(
    report_id: str,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    report = db.get(MedicalReport, report_id)
    if not report or report.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Report not found")

    data = get_report_bytes(report)
    if not data:
        raise HTTPException(status_code=404, detail="File not found")

    record_access(
        db, "report.file.read",
        actor_id=current_user.id, subject_id=report.user_id,
        resource_type="MedicalReport", resource_id=report.id, request=request,
    )

    from fastapi.responses import Response
    return Response(
        media_type=report.file_content_type or "application/octet-stream",
        content=data,
        headers={"Content-Disposition": f"inline; filename={report.file_name}"}
    )


@router.get("/{report_id}/lab-analysis", response_model=LabAnalysisResponse)
async def get_lab_analysis(
    report_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    report = db.get(MedicalReport, report_id)
    if not report or report.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Report not found")

    findings = apply_overrides(analyze_lab_text(report.extracted_text), report.lab_overrides)
    summary = summarize_findings(findings)
    return LabAnalysisResponse(
        overall=summary["overall"],
        total=summary["total"],
        abnormal_count=summary["abnormal_count"],
        findings=[LabFinding(**f) for f in findings],
    )


class LabOverrideItem(BaseModel):
    value: float
    unit: Optional[str] = None


class LabOverridesUpdate(BaseModel):
    overrides: dict[str, LabOverrideItem]


@router.put("/{report_id}/lab-values", response_model=LabAnalysisResponse)
async def update_lab_values(
    report_id: str,
    payload: LabOverridesUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    """Correct OCR'd lab values by hand. The parser re-runs over the stored
    text every time, so the corrections are applied on top of the findings —
    no re-OCR, and they survive future parser changes."""
    report = db.get(MedicalReport, report_id)
    if not report or report.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Report not found")

    for name, item in payload.overrides.items():
        spec = REFERENCE_RANGES.get(name)
        if spec is None:
            raise HTTPException(status_code=400, detail=f"Unknown analyte: {name}")
        if item.unit:
            units = {u for u, _, _ in spec[2]}
            if item.unit not in units:
                raise HTTPException(
                    status_code=400,
                    detail=f"Unit '{item.unit}' is not valid for {name}",
                )

    # Merge into whatever is already stored: clients send only the finding
    # they corrected, and a bare assignment would silently drop the
    # corrections made to the other analytes earlier. A fresh dict matters —
    # the loaded value is the exact object the attribute already holds, so
    # mutating and re-assigning it in place is a no-op for SQLAlchemy.
    existing = {}
    if isinstance(report.lab_overrides, dict):
        existing = dict(report.lab_overrides)
    elif isinstance(report.lab_overrides, str):
        try:
            parsed = json.loads(report.lab_overrides)
        except (ValueError, TypeError):
            parsed = None
        if isinstance(parsed, dict):
            existing = parsed
    existing.update({
        name: item.model_dump(exclude_none=True)
        for name, item in payload.overrides.items()
    })
    report.lab_overrides = existing
    db.add(report)
    db.commit()

    findings = apply_overrides(analyze_lab_text(report.extracted_text), report.lab_overrides)
    summary = summarize_findings(findings)
    return LabAnalysisResponse(
        overall=summary["overall"],
        total=summary["total"],
        abnormal_count=summary["abnormal_count"],
        findings=[LabFinding(**f) for f in findings],
    )