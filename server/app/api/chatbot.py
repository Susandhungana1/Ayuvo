from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
import httpx

from app.core.config import settings
from app.api.auth import get_current_user
from app.models.models import User

router = APIRouter()

SYSTEM_PROMPT = (
    "You are a knowledgeable health assistant. Answer questions ONLY about health, "
    "diseases, medicines, symptoms, nutrition, fitness, and wellness. "
    "If a question is outside these topics, politely decline to answer. "
    "Always include a disclaimer that you are AI and not a substitute for "
    "professional medical advice. Keep responses clear, concise, and helpful."
)


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]


class ChatResponse(BaseModel):
    reply: str


@router.post("", response_model=ChatResponse)
async def chat(request: ChatRequest, current_user: User = Depends(get_current_user)):
    if not settings.groq_api_key:
        raise HTTPException(status_code=500, detail="Groq API key not configured")

    groq_messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    groq_messages.extend(
        {"role": m.role, "content": m.content} for m in request.messages
    )

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {settings.groq_api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": "llama-3.3-70b-versatile",
                "messages": groq_messages,
                "temperature": 0.7,
                "max_tokens": 1024,
            },
        )

    if resp.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Groq API error: {resp.status_code} {resp.text}",
        )

    data = resp.json()
    reply = data["choices"][0]["message"]["content"]
    return ChatResponse(reply=reply)
