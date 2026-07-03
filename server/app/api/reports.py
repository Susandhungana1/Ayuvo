import uuid
import httpx
import os
from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from sqlmodel import Session, select
import json
import io
from PIL import Image
import pytesseract

from app.api.auth import get_current_user
from app.core.config import get_session, settings
from app.models.models import User, MedicalReport, MedicalReportType, MedicalDocument

router = APIRouter()


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
    
    report = MedicalReport(
        user_id=current_user.id,
        report_type=report_type,
        report_date=datetime.fromisoformat(report_date) if report_date else None,
        file_name=file_name,
        file_content=content,
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
    
    db.delete(report)
    db.commit()
    return {"message": "Report deleted"}


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
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    report = db.get(MedicalReport, report_id)
    if not report or report.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Report not found")
    
    if not report.file_content:
        raise HTTPException(status_code=404, detail="File not found")
    
    from fastapi.responses import Response
    return Response(
        media_type=report.file_content_type or "application/octet-stream",
        content=report.file_content,
        headers={"Content-Disposition": f"inline; filename={report.file_name}"}
    )