from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.core.config import settings, engine
from app.core.ratelimit import limiter
from app.models.models import SQLModel

# Initialise error monitoring before anything else so startup errors are captured.
if settings.sentry_dsn:
    import sentry_sdk

    sentry_sdk.init(
        dsn=settings.sentry_dsn,
        environment=settings.environment,
        traces_sample_rate=0.1,
        # Health data is sensitive: never let request bodies/PII into Sentry.
        send_default_pii=False,
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    SQLModel.metadata.create_all(engine)
    # Deliver medicine reminders via Web Push even when the app is closed.
    from app.core.reminder_scheduler import start_scheduler, stop_scheduler

    start_scheduler()
    try:
        yield
    finally:
        stop_scheduler()


app = FastAPI(
    title="MediStore API",
    version="1.0.0",
    lifespan=lifespan,
)

# Rate limiting (slowapi): attach limiter + 429 handler.
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from app.api import auth, users, documents, reports, appointments, share, availability, medicines, chatbot, vitals, emergency, search, timeline, family, push

app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(users.router, prefix="/api/users", tags=["users"])
app.include_router(documents.router, prefix="/api/documents", tags=["documents"])
app.include_router(reports.router, prefix="/api/reports", tags=["reports"])
app.include_router(appointments.router, prefix="/api/appointments", tags=["appointments"])
app.include_router(availability.router, prefix="/api/doctors", tags=["doctors"])
app.include_router(share.router, prefix="/api/share", tags=["share"])
app.include_router(medicines.router, prefix="/api/medicines", tags=["medicines"])
app.include_router(chatbot.router, prefix="/api/chatbot", tags=["chatbot"])
app.include_router(vitals.router, prefix="/api/vitals", tags=["vitals"])
app.include_router(emergency.router, prefix="/api/emergency", tags=["emergency"])
app.include_router(search.router, prefix="/api/search", tags=["search"])
app.include_router(timeline.router, prefix="/api/timeline", tags=["timeline"])
app.include_router(family.router, prefix="/api/family", tags=["family"])
app.include_router(push.router, prefix="/api/push", tags=["push"])


@app.get("/")
async def root():
    return {"message": "MediStore API"}


@app.get("/health")
async def health():
    """Liveness + DB readiness probe for uptime monitoring."""
    from sqlalchemy import text

    db_ok = True
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception:
        db_ok = False
    return Response(
        content='{"status": "ok", "database": %s}' % ("true" if db_ok else "false"),
        media_type="application/json",
        status_code=200 if db_ok else 503,
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=3001)