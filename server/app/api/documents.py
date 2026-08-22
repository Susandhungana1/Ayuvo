from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Request
from pydantic import BaseModel, field_validator
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
    # When the visit actually happened. Optional: omitted, the row is stamped
    # with "now" exactly as before, so every existing caller is unaffected.
    checkup_date: Optional[datetime] = None

    @field_validator("checkup_date", mode="before")
    @classmethod
    def blank_means_absent(cls, v):
        """Treat "" as "not supplied" rather than a parse error.

        front/ posts this field from a date input whose initial state is an
        empty string. It was silently discarded before this field existed, so
        an empty value must keep behaving like an omission — otherwise adding
        the field turns a working request into a 422.
        """
        return v or None


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
    total: int


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
    # Assigned rather than passed to the constructor: the column's
    # default_factory only runs when the argument is absent, and passing None
    # would write a NULL into a non-nullable column.
    if doc_data.checkup_date is not None:
        document.checkup_date = doc_data.checkup_date
    db.add(document)
    db.commit()
    db.refresh(document)
    return document


@router.get("", response_model=DocumentListResponse)
async def list_documents(
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    total = len(db.exec(
        select(MedicalDocument)
        .where(MedicalDocument.user_id == current_user.id)
    ).all())
    documents = db.exec(
        select(MedicalDocument)
        .where(MedicalDocument.user_id == current_user.id)
        .order_by(MedicalDocument.checkup_date.desc())
        .offset(offset)
        .limit(limit)
    ).all()
    return DocumentListResponse(
        documents=[
            DocumentResponse.model_validate(doc, from_attributes=True)
            for doc in documents
        ],
        total=total,
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
    request: Request,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    document = db.get(MedicalDocument, doc_id)
    if not document or document.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Document not found")
    
    declared = request.headers.get("content-length")
    if declared and declared.isdigit() and int(declared) > MAX_FILE_SIZE + 65536:
        raise HTTPException(status_code=413, detail="File size exceeds 10MB limit")
    content = await file.read(MAX_FILE_SIZE + 1)

    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File size exceeds 10MB limit")

    file_name = storage.safe_filename(file.filename)

    storage_key = storage.save_file(
        content, original_name=file_name, prefix="documents",
        content_type=file.content_type,
    )

    medical_file = MedicalFile(
        name=file_name,
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
    
    inline = bool(inline)

    record_access(
        db, "document.file.read",
        actor_id=current_user.id, subject_id=document.user_id,
        resource_type="MedicalFile", resource_id=file.id, request=request,
    )

    from fastapi.responses import Response
    return Response(
        content=data,
        media_type=content_type,
        headers={
            "Content-Disposition": storage.safe_content_disposition(file.name, inline),
            "X-Content-Type-Options": "nosniff",
        }
    )