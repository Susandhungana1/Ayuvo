import io
import zipfile
import json
from datetime import datetime
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.config import get_session
from app.models.models import User, MedicalReport, Medicine, MedicalDocument, MedicalFile, Appointment, VitalSign, EmergencyContact

router = APIRouter()


@router.get("")
async def export_all_data(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    zip_buffer = io.BytesIO()

    with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        profile = {
            "id": current_user.id,
            "name": current_user.name,
            "email": current_user.email,
            "role": current_user.role,
            "address": current_user.address,
            "city": current_user.city,
            "blood_type": current_user.blood_type,
            "allergies": current_user.allergies,
            "medical_conditions": current_user.medical_conditions,
            "created_at": str(current_user.created_at) if current_user.created_at else None,
        }
        zf.writestr("profile.json", json.dumps(profile, indent=2))

        reports = db.exec(
            select(MedicalReport)
            .where(MedicalReport.user_id == current_user.id)
            .order_by(MedicalReport.created_at.desc())
        ).all()

        for report in reports:
            report_dir = f"reports/{report.id}"
            report_data = {
                "id": report.id,
                "report_type": report.report_type.value if hasattr(report.report_type, 'value') else str(report.report_type),
                "file_name": report.file_name,
                "notes": report.notes,
                "result_summary": report.result_summary,
                "ai_report_text": report.ai_report_text,
                "extracted_text": report.extracted_text,
                "report_date": str(report.report_date) if report.report_date else None,
                "created_at": str(report.created_at) if report.created_at else None,
            }
            zf.writestr(f"{report_dir}/metadata.json", json.dumps(report_data, indent=2))
            if report.file_content:
                ext = report.file_name.split(".")[-1] if "." in report.file_name else "bin"
                zf.writestr(f"{report_dir}/file.{ext}", report.file_content)
            if report.thumbnail:
                zf.writestr(f"{report_dir}/thumbnail.txt", report.thumbnail)

        medicines = db.exec(
            select(Medicine)
            .where(Medicine.user_id == current_user.id)
            .order_by(Medicine.created_at.desc())
        ).all()

        medicines_data = []
        for m in medicines:
            medicines_data.append({
                "id": m.id,
                "name": m.name,
                "dosage": m.dosage,
                "frequency": m.frequency,
                "start_date": m.start_date,
                "end_date": m.end_date,
                "notes": m.notes,
                "created_at": str(m.created_at) if m.created_at else None,
            })
        zf.writestr("medicines.json", json.dumps(medicines_data, indent=2))

        vitals = db.exec(
            select(VitalSign)
            .where(VitalSign.user_id == current_user.id)
            .order_by(VitalSign.created_at.desc())
        ).all()

        vitals_data = []
        for v in vitals:
            vitals_data.append({
                "id": v.id,
                "blood_pressure_systolic": v.blood_pressure_systolic,
                "blood_pressure_diastolic": v.blood_pressure_diastolic,
                "heart_rate": v.heart_rate,
                "weight": v.weight,
                "blood_sugar": v.blood_sugar,
                "temperature": v.temperature,
                "oxygen_saturation": v.oxygen_saturation,
                "notes": v.notes,
                "measured_at": str(v.measured_at) if v.measured_at else None,
                "created_at": str(v.created_at) if v.created_at else None,
            })
        zf.writestr("vitals.json", json.dumps(vitals_data, indent=2))

        emergency_contacts = db.exec(
            select(EmergencyContact)
            .where(EmergencyContact.user_id == current_user.id)
        ).all()

        emergency_contacts_data = []
        for c in emergency_contacts:
            emergency_contacts_data.append({
                "id": c.id,
                "name": c.name,
                "relationship": c.relationship,
                "phone": c.phone,
                "email": c.email,
                "created_at": str(c.created_at) if c.created_at else None,
            })
        zf.writestr("emergency_contacts.json", json.dumps(emergency_contacts_data, indent=2))

        appointments = db.exec(
            select(Appointment)
            .where(Appointment.user_id == current_user.id)
            .order_by(Appointment.created_at.desc())
        ).all()

        appointments_data = []
        for a in appointments:
            appointments_data.append({
                "id": a.id,
                "title": a.title,
                "description": a.description,
                "doctor_name": a.doctor_name,
                "hospital": a.hospital,
                "appointment_date": str(a.appointment_date) if a.appointment_date else None,
                "status": a.status.value if hasattr(a.status, 'value') else str(a.status),
                "reason": a.reason,
                "created_at": str(a.created_at) if a.created_at else None,
            })
        zf.writestr("appointments.json", json.dumps(appointments_data, indent=2))

        documents = db.exec(
            select(MedicalDocument)
            .where(MedicalDocument.user_id == current_user.id)
            .where(MedicalDocument.deleted_at.is_(None))
            .order_by(MedicalDocument.created_at.desc())
        ).all()

        for doc in documents:
            doc_dir = f"documents/{doc.id}"
            doc_data = {
                "id": doc.id,
                "hospital": doc.hospital,
                "location": doc.location,
                "doctor_name": doc.doctor_name,
                "department": doc.department,
                "description": doc.description,
                "checkup_date": str(doc.checkup_date) if doc.checkup_date else None,
                "created_at": str(doc.created_at) if doc.created_at else None,
            }
            zf.writestr(f"{doc_dir}/metadata.json", json.dumps(doc_data, indent=2))

            doc_files = db.exec(
                select(MedicalFile)
                .where(MedicalFile.document_id == doc.id)
            ).all()

            for f in doc_files:
                if f.content:
                    ext = f.name.split(".")[-1] if "." in f.name else "bin"
                    zf.writestr(f"{doc_dir}/{f.id}_{f.name}", f.content)

    zip_buffer.seek(0)

    filename = f"healthtracker_export_{current_user.id}_{datetime.now().strftime('%Y%m%d')}.zip"

    return StreamingResponse(
        iter([zip_buffer.getvalue()]),
        media_type="application/zip",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )
