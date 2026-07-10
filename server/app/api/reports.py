import uuid
import httpx
import os
from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Request
from pydantic import BaseModel
from sqlmodel import Session, select
import json
import io
from PIL import Image
import pytesseract

from app.api.auth import get_current_user
from app.core.config import get_session, settings
from app.core import storage
from app.core.audit import record_access
from app.core.lab_analysis import analyze_lab_text, summarize_findings
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
    notes: Optional[str] = None


class ReportResponse(BaseModel):
    id: str
    report_type: str
    report_date: Optional[datetime]
    file_name: str
    notes: Optional[str]
    result_summary: Optional[str]
    extracted_text: Optional[str]
    ai_report_text: Optional[str]
    document_id: Optional[str] = None
    doctor_name: Optional[str] = None
    hospital: Optional[str] = None


class ReportListResponse(BaseModel):
    reports: List[ReportResponse]


class AISummary(BaseModel):
    summary: str


class AIReport(BaseModel):
    report: str


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


class ExplainResponse(BaseModel):
    explanation: str


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
        result_summary=report.result_summary,
        extracted_text=report.extracted_text,
        ai_report_text=report.ai_report_text,
        document_id=report.document_id,
        doctor_name=doctor_name,
        hospital=hospital
    )


import base64


def extract_text_from_file(content: bytes, filename: str) -> Optional[str]:
    try:
        if filename.lower().endswith(('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.tiff', '.webp')):
            image = Image.open(io.BytesIO(content))
            text = pytesseract.image_to_string(image)
            if text.strip():
                return text.strip()
        elif filename.lower().endswith('.pdf'):
            import fitz
            doc = fitz.open(stream=io.BytesIO(content), filetype="pdf")
            text = ""
            for page in doc:
                text += page.get_text()
            if text.strip():
                return text.strip()
    except Exception as e:
        print(f"OCR error: {e}")
    return None


async def generate_ai_summary(report_data: str, notes: Optional[str] = None) -> Optional[str]:
    if not settings.openrouter_api_key:
        return None
    
    prompt = f"""You are a medical assistant. Analyze this blood test report and provide a clear, easy-to-understand summary.

Please structure your response as:
1. OVERALL STATUS: (Normal/Abnormal)
2. KEY FINDINGS: (List the most important values that are outside normal range)
3. RECOMMENDATIONS: (If needed, based on the results)

Focus on values that are HIGH or LOW. Use simple language.

Report data:
{report_data}"""

    if notes:
        prompt += f"\n\nPatient Notes: {notes}"
    
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.openrouter_api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": "openai/gpt-4o-mini",
                    "messages": [
                        {
                            "role": "system",
                            "content": "You are a helpful medical assistant. Provide clear, concise summaries."
                        },
                        {
                            "role": "user",
                            "content": prompt
                        }
                    ]
                }
            )
            if response.status_code == 200:
                return response.json()["choices"][0]["message"]["content"]
    except Exception as e:
        print(f"AI summary error: {e}")
    return None


async def generate_formal_ai_report(report_type: str, extracted_text: str, notes: Optional[str] = None, report_date: Optional[str] = None) -> Optional[str]:
    if not settings.openrouter_api_key:
        return None
    
    prompt = f"""You are a medical report analyst. Based on the following medical report data, generate a comprehensive, formal, and well-structured medical report.

Format the report with the following sections:

================================================================================
                        FORMAL MEDICAL REPORT
================================================================================

REPORT TYPE: {report_type.replace('_', ' ').title()}
REPORT DATE: {report_date or 'Not specified'}

--------------------------------------------------------------------------------
1.  PATIENT INFORMATION
    - (Summarize patient context from notes if available)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
2.  REPORT CLASSIFICATION
    - Type of examination/analysis performed
    - Date of analysis
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
3.  RESULTS & FINDINGS
    (Present all extracted values in a structured format with reference ranges
     where applicable. Clearly indicate which values are within normal range
     and which are outside.)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
4.  INTERPRETATION & ANALYSIS
    (Provide a detailed medical interpretation of the findings. Explain what
     abnormal results may indicate and their potential implications.)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
5.  CLINICAL CORRELATION
    (Correlate findings with patient notes and symptoms if provided.)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
6.  RECOMMENDATIONS & FOLLOW-UP
    (Provide specific recommendations based on the findings. Include suggested
     follow-up tests, lifestyle modifications, or specialist referrals if
     applicable.)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
7.  CONCLUSION
    (Summarize the overall health status based on this report.)
--------------------------------------------------------------------------------

Report data to analyze:
{extracted_text}"""

    if notes:
        prompt += f"\n\nPatient Notes/Context:\n{notes}"
    
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.openrouter_api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": "openai/gpt-4o-mini",
                    "messages": [
                        {
                            "role": "system",
                            "content": "You are a senior medical report analyst. Generate formal, detailed, and structured medical reports. Use professional medical terminology while remaining clear and concise."
                        },
                        {
                            "role": "user",
                            "content": prompt
                        }
                    ]
                }
            )
            if response.status_code == 200:
                return response.json()["choices"][0]["message"]["content"]
    except Exception as e:
        print(f"AI formal report error: {e}")
    return None


async def generate_plain_explanation(report_type: str, extracted_text: str) -> Optional[str]:
    """Explain a report in plain, patient-friendly language using Groq (free tier)."""
    if not settings.groq_api_key:
        return None

    prompt = (
        "Explain the following medical report to a patient with no medical "
        "background. Use simple, reassuring, everyday language. Define any medical "
        "terms. Use short bullet points. Do NOT give a diagnosis or prescribe "
        "treatment. End with a reminder to consult their doctor.\n\n"
        f"Report type: {report_type.replace('_', ' ').title()}\n\n"
        f"Report content:\n{extracted_text}"
    )
    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
            resp = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.groq_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "llama-3.3-70b-versatile",
                    "messages": [
                        {"role": "system", "content": "You are a caring medical explainer for patients."},
                        {"role": "user", "content": prompt},
                    ],
                    "temperature": 0.5,
                    "max_tokens": 800,
                },
            )
            if resp.status_code == 200:
                return resp.json()["choices"][0]["message"]["content"]
            print(f"Groq explain error: {resp.status_code} {resp.text}")
    except Exception as e:
        print(f"Plain explanation error: {e}")
    return None


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
    
    extracted_text = extract_text_from_file(content, file_name)

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
    
    if extracted_text:
        summary = await generate_ai_summary(extracted_text, notes)
        if summary:
            report.result_summary = summary
        ai_report = await generate_formal_ai_report(
            report_type=report.report_type,
            extracted_text=extracted_text,
            notes=notes,
            report_date=str(report.report_date) if report.report_date else None
        )
        if ai_report:
            report.ai_report_text = ai_report
        if summary or ai_report:
            db.add(report)
            db.commit()
            db.refresh(report)
    
    return _build_report_response(report, db)


@router.get("/ai-summary", response_model=AISummary)
async def get_ai_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    reports = db.exec(
        select(MedicalReport)
        .where(MedicalReport.user_id == current_user.id)
        .order_by(MedicalReport.created_at.desc())
        .limit(5)
    ).all()
    
    if not reports:
        return AISummary(summary="No reports available")
    
    report_text = "\n".join([
        f"{r.report_type}: {r.extracted_text or r.notes or 'No details'}"
        for r in reports
    ])
    
    summary = await generate_ai_summary(report_text)
    return AISummary(summary=summary or "Unable to generate summary")


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


@router.get("/{report_id}/ai-report", response_model=AIReport)
async def get_ai_report(
    report_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    report = db.get(MedicalReport, report_id)
    if not report or report.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Report not found")
    
    return AIReport(report=report.ai_report_text or "No AI report available")


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


@router.post("/{report_id}/explain", response_model=ExplainResponse)
async def explain_report(
    report_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    report = db.get(MedicalReport, report_id)
    if not report or report.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Report not found")

    if not report.extracted_text:
        raise HTTPException(status_code=400, detail="No readable text found in this report")

    explanation = await generate_plain_explanation(report.report_type, report.extracted_text)
    if not explanation:
        raise HTTPException(status_code=503, detail="AI explanation is unavailable (no API key configured)")
    return ExplainResponse(explanation=explanation)