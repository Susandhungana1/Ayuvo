from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.auth import get_current_user
from app.core.config import get_session
from app.models.models import User, ChatMessage, Doctor

router = APIRouter()


class MessageCreate(BaseModel):
    message: str


class MessageResponse(BaseModel):
    id: str
    sender_id: str
    receiver_id: str
    message: str
    read: bool
    created_at: datetime


class ConversationResponse(BaseModel):
    messages: List[MessageResponse]


@router.get("/{doctor_id}", response_model=ConversationResponse)
async def get_conversation(
    doctor_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    doctor = db.get(Doctor, doctor_id)
    if not doctor or not doctor.verified:
        raise HTTPException(status_code=404, detail="Doctor not found or not verified")
    
    messages = db.exec(
        select(ChatMessage)
        .where(
            ((ChatMessage.sender_id == current_user.id) & (ChatMessage.receiver_id == doctor_id)) |
            ((ChatMessage.sender_id == doctor_id) & (ChatMessage.receiver_id == current_user.id))
        )
        .order_by(ChatMessage.created_at.asc())
    ).all()
    
    return ConversationResponse(
        messages=[
            MessageResponse(
                id=m.id,
                sender_id=m.sender_id,
                receiver_id=m.receiver_id,
                message=m.message,
                read=m.read,
                created_at=m.created_at
            )
            for m in messages
        ]
    )


@router.get("/my-messages", response_model=ConversationResponse)
async def get_my_messages(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    messages = db.exec(
        select(ChatMessage)
        .where(
            (ChatMessage.sender_id == current_user.id) |
            (ChatMessage.receiver_id == current_user.id)
        )
        .order_by(ChatMessage.created_at.asc())
    ).all()
    
    return ConversationResponse(
        messages=[
            MessageResponse(
                id=m.id,
                sender_id=m.sender_id,
                receiver_id=m.receiver_id,
                message=m.message,
                read=m.read,
                created_at=m.created_at
            )
            for m in messages
        ]
    )


@router.post("/{doctor_id}", response_model=MessageResponse)
async def send_message(
    doctor_id: str,
    message_data: MessageCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    doctor = db.get(Doctor, doctor_id)
    if not doctor or not doctor.verified:
        raise HTTPException(status_code=404, detail="Doctor not found or not verified")
    
    message = ChatMessage(
        sender_id=current_user.id,
        receiver_id=doctor.user_id,
        message=message_data.message
    )
    db.add(message)
    db.commit()
    db.refresh(message)
    
    return MessageResponse(
        id=message.id,
        sender_id=message.sender_id,
        receiver_id=message.receiver_id,
        message=message.message,
        read=message.read,
        created_at=message.created_at
    )


@router.post("/send-to-user/{user_id}", response_model=MessageResponse)
async def send_message_to_user(
    user_id: str,
    message_data: MessageCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    # Verify current user is a doctor
    if current_user.role not in ["DOCTOR", "ADMIN"]:
        raise HTTPException(status_code=403, detail="Only doctors can use this endpoint")
    
    # Verify receiver exists
    receiver = db.get(User, user_id)
    if not receiver:
        raise HTTPException(status_code=404, detail="User not found")
    
    message = ChatMessage(
        sender_id=current_user.id,
        receiver_id=user_id,
        message=message_data.message
    )
    db.add(message)
    db.commit()
    db.refresh(message)
    
    return MessageResponse(
        id=message.id,
        sender_id=message.sender_id,
        receiver_id=message.receiver_id,
        message=message.message,
        read=message.read,
        created_at=message.created_at
    )


# Get doctor's conversations with patients
@router.get("/doctor/conversations")
async def get_doctor_conversations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    if current_user.role not in ["DOCTOR", "ADMIN"]:
        raise HTTPException(status_code=403, detail="Only doctors can access this resource")
    
    doctor = db.exec(select(Doctor).where(Doctor.user_id == current_user.id)).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor profile not found")
    
    # Get all messages where doctor is receiver (messages from patients to doctor)
    messages = db.exec(
        select(ChatMessage)
        .where(ChatMessage.receiver_id == current_user.id)
        .order_by(ChatMessage.created_at.desc())
    ).all()
    
    # Group by sender_id (patient)
    conversations = {}
    for msg in messages:
        if msg.sender_id not in conversations:
            user = db.get(User, msg.sender_id)
            conversations[msg.sender_id] = {
                "patient_id": msg.sender_id,
                "patient_name": user.name if user else "Unknown",
                "last_message": msg.message,
                "last_time": msg.created_at,
                "unread_count": 0
            }
        if not msg.read:
            conversations[msg.sender_id]["unread_count"] += 1
    
    return list(conversations.values())


# Get doctors list
@router.get("", response_model=List[dict])
async def get_doctors(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session)
):
    doctors = db.exec(
        select(Doctor).where(Doctor.verified == True)
    ).all()
    
    result = []
    for d in doctors:
        doctor_user = db.get(User, d.user_id)
        result.append({
            "id": d.id,
            "name": doctor_user.name if doctor_user else "Unknown",
            "email": doctor_user.email if doctor_user else ""
        })
    
    return result