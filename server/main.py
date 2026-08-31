from contextlib import asynccontextmanager
import os
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
    title="Ayuvo API",
    version="1.0.0",
    lifespan=lifespan,
)

# Rate limiting (slowapi): attach limiter + 429 handler.
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Beyond the explicit CORS_ORIGINS allowlist, also accept THIS project's Vercel
# domains via regex: the production alias (front-*.vercel.app, incl.
# front-five-woad-12), the Ayuvo web (ayuvo-health.vercel.app, legacy
# medistore-health), the Share reader's standalone app
# (ayuvo-share-*.vercel.app, legacy medistore-share-*.vercel.app), and git
# preview deploys. Scoped to our own project's subdomains — NOT all of
# *.vercel.app — so renaming or redeploying the frontend never silently
# breaks API calls, without hand-editing CORS_ORIGINS on Render each time.
VERCEL_ORIGIN_REGEX = r"^https://(ayuvo-health|ayuvo-share[\w-]*|front-ayuvo-app|medistore-health|medistore-share[\w-]*|front-medistore-app|front-git-[\w-]*susan[\w-]*|front-five-woad-12)\.vercel\.app$"

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_origin_regex=VERCEL_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class SecurityHeadersMiddleware:
    """Add the browser-hardening headers every response should carry.

    The API serves no HTML of its own, so a strict CSP belongs to the frontend
    (which does not set one yet). This layer covers HSTS, sniffing, framing and
    referrer leakage; headers already set by an endpoint are left untouched.
    """

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)

        async def send_wrapper(message):
            if message["type"] == "http.response.start":
                message.setdefault("headers", [])
                existing = {k.lower() for k, _ in message["headers"]}
                for name, value in (
                    (b"strict-transport-security",
                     b"max-age=31536000; includeSubDomains"),
                    (b"x-content-type-options", b"nosniff"),
                    (b"x-frame-options", b"SAMEORIGIN"),
                    (b"referrer-policy", b"strict-origin-when-cross-origin"),
                ):
                    if name not in existing:
                        message["headers"].append((name, value))
            await send(message)

        await self.app(scope, receive, send_wrapper)


app.add_middleware(SecurityHeadersMiddleware)

from app.api import auth, users, documents, reports, appointments, share, availability, medicines, vitals, emergency, search, timeline, push, care

app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(users.router, prefix="/api/users", tags=["users"])
app.include_router(documents.router, prefix="/api/documents", tags=["documents"])
app.include_router(reports.router, prefix="/api/reports", tags=["reports"])
app.include_router(appointments.router, prefix="/api/appointments", tags=["appointments"])
app.include_router(availability.router, prefix="/api/doctors", tags=["doctors"])
app.include_router(share.router, prefix="/api/share", tags=["share"])
app.include_router(medicines.router, prefix="/api/medicines", tags=["medicines"])
app.include_router(vitals.router, prefix="/api/vitals", tags=["vitals"])
app.include_router(emergency.router, prefix="/api/emergency", tags=["emergency"])
app.include_router(search.router, prefix="/api/search", tags=["search"])
app.include_router(timeline.router, prefix="/api/timeline", tags=["timeline"])
app.include_router(push.router, prefix="/api/push", tags=["push"])
app.include_router(care.router, prefix="/api/care", tags=["care"])


@app.get("/")
async def root():
    return {"message": "Ayuvo API"}


@app.get("/health")
async def health():
    """Liveness + DB readiness probe for uptime monitoring."""
    from sqlalchemy import text

    import json

    db_ok = True
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception:
        db_ok = False

    # Which mail transport is live, so a misconfigured deploy is one curl away.
    # /forgot-password answers identically whether or not mail went out, so
    # without this the only symptom of an unset key is a reset email that
    # never arrives. Names the transport, never the credential.
    if settings.brevo_api_key:
        email = "brevo"
    elif settings.smtp_host:
        email = "smtp"
    else:
        email = "none"

    # Same reasoning as `email` above: a feature flag that didn't take effect is
    # invisible from outside. The care endpoints require auth, so an anonymous
    # request gets 401 whether the feature is on or off — there is otherwise no
    # way to confirm a flag flip actually reached the running process. Reports
    # the flag's state, which is not a secret.
    from app.core.fcm import fcm_available
    from app.core.webpush import push_available
    from app.core.reminder_scheduler import reminders_available, is_running

    return Response(
        content=json.dumps({
            "status": "ok",
            "database": db_ok,
            "email": email,
            "caretaker": settings.caretaker_enabled,
            "doctor_confirms_bookings": settings.doctor_confirms_bookings,
            "frontend_url": settings.frontend_url,
            "fcm": fcm_available(),
            "webpush": push_available(),
            "scheduler": is_running(),
        }),
        media_type="application/json",
        status_code=200 if db_ok else 503,
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=3001)