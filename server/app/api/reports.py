import uuid
import os
from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Request
from pydantic import BaseModel, Field
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.config import get_session, settings
from app.core import storage
from app.core.audit import record_access
from app.core.lab_analysis import analyze_lab_text, summarize_findings
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
        document_id=report.document_id,
        doctor_name=doctor_name,
        hospital=hospital
    )


MAX_FILE_SIZE = 10 * 1024 * 1024


@router.post("", response_model=ReportResponse)
async def create_report(
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
    
    extracted_text = await extract_report_text(content, file_name)

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
        extracted_text=extracted_text
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    
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
        for f in analyze_lab_text(r.extracted_text):
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

    findings = analyze_lab_text(report.extracted_text)
    summary = summarize_findings(findings)
    return LabAnalysisResponse(
        overall=summary["overall"],
        total=summary["total"],
        abnormal_count=summary["abnormal_count"],
        findings=[LabFinding(**f) for f in findings],
    )