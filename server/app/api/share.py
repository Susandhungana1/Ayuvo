import secrets
import base64
import hashlib
import secrets as _secrets
from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.api.reports import get_report_bytes
from app.core.config import get_session
from app.core.audit import record_access
from app.core.lab_analysis import analyze_lab_text, summarize_findings
from app.core.ratelimit import limiter, user_key
from app.models.models import (
    User, MedicalReport, Medicine, ShareLink, EmergencyContact, ClaimedShare,
)

router = APIRouter()


def _hash_pin(token: str, pin: str) -> str:
    """Hash a share PIN keyed by the link's token. The token is already random
    and secret, so the pair is unique per link and the PIN alone leaks nothing."""
    return hashlib.sha256(f"{token}:{pin}".encode()).hexdigest()


class ShareResponse(BaseModel):
    token: str
    expires_at: datetime
    pin: Optional[str] = None


class SharedReportResponse(BaseModel):
    id: str
    report_type: str
    file_name: str
    file_content: str
    notes: Optional[str]
    extracted_text: Optional[str]
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
    expires_hours: int = Query(default=24, ge=1, le=72),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    reports = db.exec(
        select(MedicalReport).where(MedicalReport.user_id == current_user.id)
    ).all()

    medicines = db.exec(
        select(Medicine).where(
            Medicine.user_id == current_user.id,
            Medicine.deleted_at.is_(None),
        )
    ).all()

    emergency_contacts = db.exec(
        select(EmergencyContact).where(EmergencyContact.user_id == current_user.id)
    ).all()

    if not reports and not medicines and not emergency_contacts and not current_user.blood_type and not current_user.allergies and not current_user.medical_conditions:
        raise HTTPException(status_code=400, detail="Nothing to share")

    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(hours=expires_hours)

    # A whole-record share exposes every report and medicine, so it gets a
    # 6-digit PIN the sharer must hand over separately (or read out). A
    # photographed QR alone is useless without it.
    pin = f"{_secrets.randbelow(1_000_000):06d}"
    share_link = ShareLink(
        token=token,
        report_id=None,
        user_id=current_user.id,
        all_reports=True,
        pin_hash=_hash_pin(token, pin),
        expires_at=expires_at
    )
    db.add(share_link)
    db.commit()
    
    return ShareResponse(token=token, expires_at=expires_at, pin=pin)


@router.get("/qr-code/{token}", response_model=UserAllReportsResponse)
@limiter.limit("20/hour")
async def access_all_shared_reports(
    token: str,
    request: Request,
    pin: Optional[str] = Query(default=None),
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

    if share_link.pin_hash is not None:
        if not pin:
            raise HTTPException(
                status_code=401,
                detail="This health record is PIN-protected. Ask the owner for the 6-digit PIN.",
            )
        if _hash_pin(token, pin) != share_link.pin_hash:
            raise HTTPException(status_code=401, detail="Incorrect PIN")
        record_access(
            db, "share.view.all.pin_ok",
            subject_id=share_link.user_id, resource_type="ShareLink",
            resource_id=share_link.id, request=request, detail=f"token={token[:8]}…",
        )
    else:
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
            extracted_text=report.extracted_text,
            doctor_name=report.doctor_name,
            hospital=report.hospital,
            created_at=str(report.created_at) if report.created_at else None
        ))
    
    medicines = db.exec(
        select(Medicine)
        .where(
            Medicine.user_id == share_link.user_id,
            Medicine.deleted_at.is_(None),
        )
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


# --- Claiming ----------------------------------------------------------------
#
# Everything from here to the next banner is authenticated, and every route is
# declared ABOVE the `/{token}` catch-alls on purpose: FastAPI matches in
# declaration order, so a literal segment like `/received` registered after
# `GET /{token}` would be read as a token and never reached.


class ClaimSummary(BaseModel):
    id: str
    kind: str
    owner_name: str
    owner_id: str
    report_count: int
    claimed_at: str


class ReceivedSharesResponse(BaseModel):
    shares: List[ClaimSummary]


class ReceivedShareDetail(BaseModel):
    id: str
    owner_name: str
    owner_id: str
    kind: str
    claimed_at: str
    reports: List[SharedReportResponse]
    # Reports present at claim time that the owner has since deleted. Surfaced
    # rather than silently dropped: a recipient looking at four of five reports
    # should know the fifth was withdrawn, not assume it never existed.
    withdrawn_count: int


class ClaimAuditEntry(BaseModel):
    id: str
    recipient_name: str
    recipient_id: str
    kind: str
    report_count: int
    claimed_at: str
    status: str


class ClaimAuditResponse(BaseModel):
    claims: List[ClaimAuditEntry]


class MessageResponse(BaseModel):
    message: str


@router.post("/{token}/claim", response_model=ClaimSummary)
@limiter.limit("30/hour", key_func=user_key)
async def claim_share(
    token: str,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Keep a share that is currently readable, so it outlives the link.

    Claiming grants the recipient nothing they cannot already see — the link is
    open in front of them — it only stops the access expiring. The link must
    still be valid: you may keep what you are being shown, never resurrect a
    share whose window has closed.
    """
    share_link = db.exec(select(ShareLink).where(ShareLink.token == token)).first()
    if not share_link:
        raise HTTPException(status_code=404, detail="Share link not found")
    if share_link.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=410,
            detail="This link has expired, so it can no longer be saved. Ask the sender for a new one.",
        )

    if share_link.user_id == current_user.id:
        raise HTTPException(
            status_code=400, detail="This is your own record — it's already in your account."
        )

    owner = db.get(User, share_link.user_id)
    if not owner:
        raise HTTPException(status_code=404, detail="Share link not found")

    # Freeze the visible set. For a whole-record link that is every report the
    # owner has right now; for a single-report link it is just that one.
    if share_link.all_reports:
        kind = "all"
        report_ids = [
            r.id
            for r in db.exec(
                select(MedicalReport)
                .where(MedicalReport.user_id == share_link.user_id)
                .order_by(MedicalReport.created_at.desc())
            ).all()
        ]
    else:
        kind = "report"
        report_ids = [share_link.report_id] if share_link.report_id else []

    existing = db.exec(
        select(ClaimedShare)
        .where(ClaimedShare.recipient_id == current_user.id)
        .where(ClaimedShare.token == token)
        .where(ClaimedShare.status == "active")
    ).first()
    if existing:
        # Idempotent: a second "Save" on the same link is a no-op, not an error
        # and not a duplicate row.
        return ClaimSummary(
            id=existing.id,
            kind=existing.kind,
            owner_name=existing.owner_name,
            owner_id=existing.owner_id,
            report_count=len(existing.report_ids),
            claimed_at=str(existing.claimed_at),
        )

    claim = ClaimedShare(
        token=token,
        recipient_id=current_user.id,
        owner_id=share_link.user_id,
        kind=kind,
        report_ids=report_ids,
        owner_name=owner.name,
    )
    db.add(claim)
    db.commit()
    db.refresh(claim)

    # The one audit line that names a share recipient. Every other share event
    # can only record an IP, because until now nobody had to identify themselves.
    record_access(
        db, "share.claimed",
        actor_id=current_user.id, subject_id=share_link.user_id,
        resource_type="ClaimedShare", resource_id=claim.id,
        request=request, detail=f"kind={kind} reports={len(report_ids)}",
    )

    return ClaimSummary(
        id=claim.id,
        kind=claim.kind,
        owner_name=claim.owner_name,
        owner_id=claim.owner_id,
        report_count=len(claim.report_ids),
        claimed_at=str(claim.claimed_at),
    )


@router.get("/received", response_model=ReceivedSharesResponse)
async def list_received_shares(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Shares this user has kept — the "Shared with me" list."""
    claims = db.exec(
        select(ClaimedShare)
        .where(ClaimedShare.recipient_id == current_user.id)
        .where(ClaimedShare.status == "active")
        .order_by(ClaimedShare.claimed_at.desc())
    ).all()

    return ReceivedSharesResponse(
        shares=[
            ClaimSummary(
                id=c.id,
                kind=c.kind,
                owner_name=c.owner_name,
                owner_id=c.owner_id,
                report_count=len(c.report_ids),
                claimed_at=str(c.claimed_at),
            )
            for c in claims
        ]
    )


@router.get("/received/{claim_id}", response_model=ReceivedShareDetail)
async def read_received_share(
    claim_id: str,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Read a kept share.

    Resolves the frozen ID list against live rows, so a report the owner has
    since deleted simply stops appearing. Deliberately does NOT re-check the
    share token — it has usually expired by now, and surviving that is the
    whole point of a claim. Also deliberately carries no emergency profile:
    the reader shows that live, but a permanent copy of someone's blood type,
    allergies and next-of-kin phone numbers is a different grant from the
    report they meant to send.
    """
    claim = db.get(ClaimedShare, claim_id)
    if not claim or claim.recipient_id != current_user.id or claim.status != "active":
        raise HTTPException(status_code=404, detail="Not found")

    reports = []
    for rid in claim.report_ids:
        report = db.get(MedicalReport, rid)
        # Ownership re-checked on every read: if a report somehow changed hands,
        # the claim must not follow it.
        if not report or report.user_id != claim.owner_id:
            continue

        file_content_b64 = ""
        report_bytes = get_report_bytes(report)
        if report_bytes:
            file_content_b64 = base64.b64encode(report_bytes).decode("utf-8")

        reports.append(SharedReportResponse(
            id=report.id,
            report_type=report.report_type,
            file_name=report.file_name,
            file_content=file_content_b64,
            notes=report.notes,
            extracted_text=report.extracted_text,
            doctor_name=report.doctor_name,
            hospital=report.hospital,
            created_at=str(report.created_at) if report.created_at else None,
        ))

    record_access(
        db, "share.received.view",
        actor_id=current_user.id, subject_id=claim.owner_id,
        resource_type="ClaimedShare", resource_id=claim.id, request=request,
    )

    return ReceivedShareDetail(
        id=claim.id,
        owner_name=claim.owner_name,
        owner_id=claim.owner_id,
        kind=claim.kind,
        claimed_at=str(claim.claimed_at),
        reports=reports,
        withdrawn_count=len(claim.report_ids) - len(reports),
    )


@router.delete("/received/{claim_id}", response_model=MessageResponse)
async def drop_received_share(
    claim_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Recipient removes a share from their own list."""
    claim = db.get(ClaimedShare, claim_id)
    if not claim or claim.recipient_id != current_user.id or claim.status != "active":
        raise HTTPException(status_code=404, detail="Not found")

    claim.status = "revoked"
    claim.revoked_at = datetime.utcnow()
    claim.revoked_by = current_user.id
    db.add(claim)
    db.commit()
    return MessageResponse(message="Removed from your shared records")


@router.get("/claims", response_model=ClaimAuditResponse)
async def list_claims_on_my_records(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Who has kept a copy of this user's records.

    The accountability half of the feature: anonymous link views can only ever
    be logged as an IP, but a claim has a name attached.
    """
    claims = db.exec(
        select(ClaimedShare)
        .where(ClaimedShare.owner_id == current_user.id)
        .where(ClaimedShare.status == "active")
        .order_by(ClaimedShare.claimed_at.desc())
    ).all()

    entries = []
    for c in claims:
        recipient = db.get(User, c.recipient_id)
        entries.append(ClaimAuditEntry(
            id=c.id,
            recipient_name=recipient.name if recipient else "Deleted account",
            recipient_id=c.recipient_id,
            kind=c.kind,
            report_count=len(c.report_ids),
            claimed_at=str(c.claimed_at),
            status=c.status,
        ))

    return ClaimAuditResponse(claims=entries)


@router.delete("/claims/{claim_id}", response_model=MessageResponse)
async def revoke_claim(
    claim_id: str,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Owner withdraws a claim on their own records.

    Cannot un-see what was already read, but it does end the ongoing access —
    the escape hatch for a link that reached the wrong person.
    """
    claim = db.get(ClaimedShare, claim_id)
    if not claim or claim.owner_id != current_user.id or claim.status != "active":
        raise HTTPException(status_code=404, detail="Not found")

    claim.status = "revoked"
    claim.revoked_at = datetime.utcnow()
    claim.revoked_by = current_user.id
    db.add(claim)
    db.commit()

    record_access(
        db, "share.claim.revoked",
        actor_id=current_user.id, subject_id=claim.recipient_id,
        resource_type="ClaimedShare", resource_id=claim.id, request=request,
    )
    return MessageResponse(message="Access withdrawn")


# --- Single-report links -----------------------------------------------------


@router.post("/{report_id}", response_model=ShareResponse)
async def create_share_link(
    report_id: str,
    expires_hours: int = Query(default=24, ge=1, le=168),
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
@limiter.limit("20/hour")
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

    # A whole-record link carries no report_id, so it cannot be read here. The
    # mirror of the all_reports check in access_all_shared_reports; without it
    # the db.get below looks up a None primary key and the endpoint 500s.
    if share_link.all_reports or not share_link.report_id:
        raise HTTPException(status_code=404, detail="Invalid share link")

    record_access(
        db, "share.view",
        subject_id=share_link.user_id, resource_type="MedicalReport",
        resource_id=share_link.report_id, request=request, detail=f"token={token[:8]}…",
    )

    # The report can be gone — the owner may have deleted it while the link was
    # still live, and a share link is not a foreign key. Same predicate as
    # _resolve_shared_report: missing, or no longer the sharer's to share.
    report = db.get(MedicalReport, share_link.report_id)
    if not report or report.user_id != share_link.user_id:
        raise HTTPException(
            status_code=404,
            detail="This report is no longer available — the sender removed it.",
        )

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
        extracted_text=report.extracted_text,
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