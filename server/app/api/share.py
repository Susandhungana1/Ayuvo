import secrets
import base64
from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.api.reports import generate_plain_explanation, get_report_bytes
from app.core.config import get_session
from app.core.audit import record_access
from app.core.lab_analysis import analyze_lab_text, summarize_findings
from app.models.models import User, MedicalReport, Medicine, ShareLink, EmergencyContact

router = APIRouter()


class ShareResponse(BaseModel):
    token: str
    expires_at: datetime


class SharedReportResponse(BaseModel):
    id: str
    report_type: str
    file_name: str
    file_content: str
    notes: Optional[str]
    result_summary: Optional[str]
    extracted_text: Optional[str]
    ai_report_text: Optional[str]
    doctor_name: Optional[str] = None
    hospital: Optional[str] = None
    created_at: Optional[str]


class ShareLinkResponse(BaseModel):
    token: str
    report_id: str
    expires_at: datetime


class ShareLinksResponse(BaseModel):
    links: List[ShareLinkResponse]


class AllReportsShareResponse(BaseModel):
    token: str
    expires_at: datetime
    reports: List[SharedReportResponse]


class MedicineShareResponse(BaseModel):
    id: str
    name: str
    dosage: str
    frequency: str
    start_date: str
    end_date: Optional[str]
    notes: Optional[str]


class EmergencyContactShare(BaseModel):
    name: str
    relationship: str
    phone: str


class EmergencyShareResponse(BaseModel):
    blood_type: Optional[str] = None
    allergies: Optional[str] = None
    medical_conditions: Optional[str] = None
    emergency_contacts: List[EmergencyContactShare] = []


class UserAllReportsResponse(BaseModel):
    user_name: str
    user_id: Optional[str] = None
    user_blood_type: Optional[str] = None
    emergency: EmergencyShareResponse = EmergencyShareResponse()
    reports: List[SharedReportResponse]
    medicines: List[MedicineShareResponse] = []


class SharedReportWithEmergencyResponse(BaseModel):
    report: SharedReportResponse
    emergency: EmergencyShareResponse = EmergencyShareResponse()
    user_name: Optional[str] = None
    user_id: Optional[str] = None
    user_blood_type: Optional[str] = None


@router.get("", response_model=ShareLinksResponse)
async def list_share_links(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    share_links = db.exec(
        select(ShareLink).where(ShareLink.user_id == current_user.id)
    ).all()
    
    return ShareLinksResponse(
        links=[
            ShareLinkResponse(
                token=link.token,
                report_id=link.report_id or "__ALL_REPORTS__",
                expires_at=link.expires_at
            )
            for link in share_links
        ]
    )


@router.post("/qr-code", response_model=ShareResponse)
async def create_all_reports_share_link(
    expires_hours: int = 24,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    reports = db.exec(
        select(MedicalReport).where(MedicalReport.user_id == current_user.id)
    ).all()

    medicines = db.exec(
        select(Medicine).where(Medicine.user_id == current_user.id)
    ).all()

    emergency_contacts = db.exec(
        select(EmergencyContact).where(EmergencyContact.user_id == current_user.id)
    ).all()

    if not reports and not medicines and not emergency_contacts and not current_user.blood_type and not current_user.allergies and not current_user.medical_conditions:
        raise HTTPException(status_code=400, detail="Nothing to share")

    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(hours=expires_hours)
    
    share_link = ShareLink(
        token=token,
        report_id=None,
        user_id=current_user.id,
        all_reports=True,
        expires_at=expires_at
    )
    db.add(share_link)
    db.commit()
    
    return ShareResponse(token=token, expires_at=expires_at)


@router.get("/qr-code/{token}", response_model=UserAllReportsResponse)
async def access_all_shared_reports(
    token: str,
    request: Request,
    db: Session = Depends(get_session)
):
    share_link = db.exec(
        select(ShareLink).where(ShareLink.token == token)
    ).first()

    if not share_link:
        raise HTTPException(status_code=404, detail="Share link not found")

    if not share_link.all_reports:
        raise HTTPException(status_code=404, detail="Invalid share link")

    if share_link.expires_at < datetime.utcnow():
        raise HTTPException(status_code=410, detail="Share link expired")

    record_access(
        db, "share.view.all",
        subject_id=share_link.user_id, resource_type="ShareLink",
        resource_id=share_link.id, request=request, detail=f"token={token[:8]}…",
    )

    reports = db.exec(
        select(MedicalReport)
        .where(MedicalReport.user_id == share_link.user_id)
        .order_by(MedicalReport.created_at.desc())
    ).all()
    
    user = db.exec(select(User).where(User.id == share_link.user_id)).first()
    user_name = user.name if user else "Unknown"
    
    emergency_info = _get_emergency_info(user, db)
    
    reports_response = []
    for report in reports:
        file_content_b64 = ""
        report_bytes = get_report_bytes(report)
        if report_bytes:
            file_content_b64 = base64.b64encode(report_bytes).decode("utf-8")

        reports_response.append(SharedReportResponse(
            id=report.id,
            report_type=report.report_type,
            file_name=report.file_name,
            file_content=file_content_b64,
            notes=report.notes,
            result_summary=report.result_summary,
            extracted_text=report.extracted_text,
            ai_report_text=report.ai_report_text,
            doctor_name=report.doctor_name,
            hospital=report.hospital,
            created_at=str(report.created_at) if report.created_at else None
        ))
    
    medicines = db.exec(
        select(Medicine)
        .where(Medicine.user_id == share_link.user_id)
        .order_by(Medicine.created_at.desc())
    ).all()

    medicines_response = [
        MedicineShareResponse(
            id=m.id,
            name=m.name,
            dosage=m.dosage,
            frequency=m.frequency,
            start_date=m.start_date,
            end_date=m.end_date,
            notes=m.notes
        )
        for m in medicines
    ]

    return UserAllReportsResponse(
        user_name=user_name,
        user_id=user.id if user else None,
        user_blood_type=user.blood_type if user else None,
        emergency=emergency_info,
        reports=reports_response,
        medicines=medicines_response
    )


def _get_emergency_info(user: User, db: Session) -> EmergencyShareResponse:
    if not user:
        return EmergencyShareResponse()
    contacts = db.exec(
        select(EmergencyContact).where(EmergencyContact.user_id == user.id)
    ).all()
    return EmergencyShareResponse(
        blood_type=user.blood_type,
        allergies=user.allergies,
        medical_conditions=user.medical_conditions,
        emergency_contacts=[
            EmergencyContactShare(name=c.name, relationship=c.relationship, phone=c.phone)
            for c in contacts
        ],
    )


@router.post("/{report_id}", response_model=ShareResponse)
async def create_share_link(
    report_id: str,
    expires_hours: int = 24,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    report = db.get(MedicalReport, report_id)
    if not report or report.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Report not found")
    
    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(hours=expires_hours)
    
    share_link = ShareLink(
        token=token,
        report_id=report_id,
        user_id=current_user.id,
        expires_at=expires_at
    )
    db.add(share_link)
    db.commit()
    
    return ShareResponse(token=token, expires_at=expires_at)


@router.get("/{token}", response_model=SharedReportWithEmergencyResponse)
async def access_shared_report(
    token: str,
    request: Request,
    db: Session = Depends(get_session)
):
    share_link = db.exec(
        select(ShareLink).where(ShareLink.token == token)
    ).first()

    if not share_link:
        raise HTTPException(status_code=404, detail="Share link not found")

    if share_link.expires_at < datetime.utcnow():
        raise HTTPException(status_code=410, detail="Share link expired")

    record_access(
        db, "share.view",
        subject_id=share_link.user_id, resource_type="MedicalReport",
        resource_id=share_link.report_id, request=request, detail=f"token={token[:8]}…",
    )

    report = db.get(MedicalReport, share_link.report_id)
    user = db.get(User, share_link.user_id)

    file_content_b64 = ""
    report_bytes = get_report_bytes(report)
    if report_bytes:
        file_content_b64 = base64.b64encode(report_bytes).decode("utf-8")

    report_response = SharedReportResponse(
        id=report.id,
        report_type=report.report_type,
        file_name=report.file_name,
        file_content=file_content_b64,
        notes=report.notes,
        result_summary=report.result_summary,
        extracted_text=report.extracted_text,
        ai_report_text=report.ai_report_text,
        doctor_name=report.doctor_name,
        hospital=report.hospital,
        created_at=str(report.created_at) if report.created_at else None
    )
    
    return SharedReportWithEmergencyResponse(
        report=report_response,
        emergency=_get_emergency_info(user, db),
        user_name=user.name if user else None,
        user_id=user.id if user else None,
        user_blood_type=user.blood_type if user else None
    )


@router.get("/{token}/ai-report")
async def get_shared_ai_report(
    token: str,
    report_id: Optional[str] = None,
    db: Session = Depends(get_session)
):
    share_link = db.exec(
        select(ShareLink).where(ShareLink.token == token)
    ).first()
    
    if not share_link:
        raise HTTPException(status_code=404, detail="Share link not found")
    
    if share_link.expires_at < datetime.utcnow():
        raise HTTPException(status_code=410, detail="Share link expired")
    
    rid = report_id or share_link.report_id
    if not rid:
        raise HTTPException(status_code=400, detail="No report specified")
    
    report = db.get(MedicalReport, rid)
    if not report:
        raise HTTPException(status_code=400, detail="Report not found")

    return {"report": report.ai_report_text or "No AI report available"}


def _resolve_shared_report(token: str, report_id: Optional[str], db: Session) -> MedicalReport:
    """Validate a share token and return the requested report, ensuring it
    belongs to the same user who created the link. Works for both single-report
    links (report_id stored on the link) and all-reports/QR links (report_id
    passed by the caller)."""
    share_link = db.exec(select(ShareLink).where(ShareLink.token == token)).first()
    if not share_link:
        raise HTTPException(status_code=404, detail="Share link not found")
    if share_link.expires_at < datetime.utcnow():
        raise HTTPException(status_code=410, detail="Share link expired")

    rid = report_id or share_link.report_id
    if not rid:
        raise HTTPException(status_code=400, detail="No report specified")

    report = db.get(MedicalReport, rid)
    if not report or report.user_id != share_link.user_id:
        raise HTTPException(status_code=404, detail="Report not found")
    return report


@router.get("/{token}/lab-analysis")
async def get_shared_lab_analysis(
    token: str,
    report_id: Optional[str] = None,
    db: Session = Depends(get_session)
):
    """Public lab-value analysis for a shared report (no login required)."""
    report = _resolve_shared_report(token, report_id, db)
    findings = analyze_lab_text(report.extracted_text)
    summary = summarize_findings(findings)
    return {
        "overall": summary["overall"],
        "total": summary["total"],
        "abnormal_count": summary["abnormal_count"],
        "findings": findings,
    }


@router.get("/{token}/explain")
async def get_shared_explanation(
    token: str,
    report_id: Optional[str] = None,
    db: Session = Depends(get_session)
):
    """Public plain-language explanation for a shared report (no login required)."""
    report = _resolve_shared_report(token, report_id, db)
    if not report.extracted_text:
        raise HTTPException(status_code=400, detail="No readable text found in this report")
    explanation = await generate_plain_explanation(report.report_type, report.extracted_text)
    if not explanation:
        raise HTTPException(status_code=503, detail="AI explanation is unavailable (no API key configured)")
    return {"explanation": explanation}


@router.delete("/{token}")
async def revoke_share_link(
    token: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    share_link = db.exec(
        select(ShareLink).where(ShareLink.token == token)
    ).first()
    
    if not share_link or share_link.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Share link not found")
    
    db.delete(share_link)
    db.commit()
    return {"message": "Share link revoked"}