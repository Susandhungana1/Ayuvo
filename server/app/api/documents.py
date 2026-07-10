from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Request
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.config import get_session
from app.core import storage
from app.core.audit import record_access
from app.models.models import User, MedicalDocument, MedicalFile

router = APIRouter()


class DocumentCreate(BaseModel):
    hospital: str
    location: Optional[str] = None
    doctor_name: Optional[str] = None
    department: Optional[str] = None
    description: Optional[str] = None


class DocumentResponse(BaseModel):
    id: str
    hospital: str
    location: Optional[str]
    doctor_name: Optional[str]
    department: Optional[str]
    description: Optional[str]
    checkup_date: datetime


class DocumentListResponse(BaseModel):
    documents: List[DocumentResponse]


class FileResponse(BaseModel):
    id: str
    name: str
    file_type: str


@router.post("", response_model=DocumentResponse)
async def create_document(
    doc_data: DocumentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    document = MedicalDocument(
        user_id=current_user.id,
        hospital=doc_data.hospital,
        location=doc_data.location,
        doctor_name=doc_data.doctor_name,
        department=doc_data.department,
        description=doc_data.description
    )
    db.add(document)
    db.commit()
    db.refresh(document)
    return document


@router.get("", response_model=DocumentListResponse)
async def list_documents(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    documents = db.exec(
        select(MedicalDocument)
        .where(MedicalDocument.user_id == current_user.id)
        .order_by(MedicalDocument.checkup_date.desc())
    ).all()
    return DocumentListResponse(
        documents=[DocumentResponse.model_validate(doc) for doc in documents]
    )


@router.get("/{doc_id}", response_model=DocumentResponse)
async def get_document(
    doc_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    document = db.get(MedicalDocument, doc_id)
    if not document or document.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Document not found")
    return document


@router.delete("/{doc_id}")
async def delete_document(
    doc_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    document = db.get(MedicalDocument, doc_id)
    if not document or document.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Document not found")
    
    files = db.exec(select(MedicalFile).where(MedicalFile.document_id == doc_id)).all()
    for f in files:
        storage.delete_file(f.storage_key)
        db.delete(f)

    db.delete(document)
    db.commit()
    return {"message": "Document deleted"}


MAX_FILE_SIZE = 10 * 1024 * 1024


@router.post("/{doc_id}/files", response_model=FileResponse)
async def upload_document_file(
    doc_id: str,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    document = db.get(MedicalDocument, doc_id)
    if not document or document.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Document not found")
    
    content = await file.read()

    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="File size exceeds 10MB limit")

    storage_key = storage.save_file(
        content, original_name=file.filename, prefix="documents",
        content_type=file.content_type,
    )

    medical_file = MedicalFile(
        name=file.filename,
        file_type="OTHER",
        storage_key=storage_key,
        content_type=file.content_type,
        document_id=doc_id
    )
    db.add(medical_file)
    db.commit()
    db.refresh(medical_file)
    
    return FileResponse(id=medical_file.id, name=medical_file.name, file_type=medical_file.file_type)


@router.get("/{doc_id}/files")
async def get_document_files(
    doc_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    document = db.get(MedicalDocument, doc_id)
    if not document or document.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Document not found")
    
    files = db.exec(select(MedicalFile).where(MedicalFile.document_id == doc_id)).all()
    
    return {
        "files": [
            {"id": f.id, "name": f.name, "file_type": f.file_type}
            for f in files
        ]
    }


@router.get("/{doc_id}/files/{file_id}")
async def download_document_file(
    doc_id: str,
    file_id: str,
    request: Request,
    inline: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    document = db.get(MedicalDocument, doc_id)
    if not document or document.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Document not found")

    file = db.get(MedicalFile, file_id)
    if not file or file.document_id != doc_id:
        raise HTTPException(status_code=404, detail="File not found")

    if file.storage_key:
        try:
            data = storage.read_file(file.storage_key)
        except FileNotFoundError:
            raise HTTPException(status_code=404, detail="File not found")
    else:
        data = file.content
    if not data:
        raise HTTPException(status_code=404, detail="File not found")

    content_type = "application/octet-stream"
    if file.name.lower().endswith(('.png', '.jpg', '.jpeg', '.gif', '.webp')):
        if file.name.lower().endswith('.png'):
            content_type = "image/png"
        elif file.name.lower().endswith('.jpg') or file.name.lower().endswith('.jpeg'):
            content_type = "image/jpeg"
        elif file.name.lower().endswith('.gif'):
            content_type = "image/gif"
        elif file.name.lower().endswith('.webp'):
            content_type = "image/webp"
    elif file.name.lower().endswith('.pdf'):
        content_type = "application/pdf"
    
    disposition = "inline" if inline else "attachment"

    record_access(
        db, "document.file.read",
        actor_id=current_user.id, subject_id=document.user_id,
        resource_type="MedicalFile", resource_id=file.id, request=request,
    )

    from fastapi.responses import Response
    return Response(
        content=data,
        media_type=content_type,
        headers={"Content-Disposition": f"{disposition}; filename={file.name}"}
    )