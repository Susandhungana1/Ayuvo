from pydantic_settings import BaseSettings
from sqlmodel import create_engine, Session


class Settings(BaseSettings):
    # --- Environment ---
    # "development" | "production". In production we refuse to boot with
    # insecure default secrets so a misconfigured deploy fails loud, not silent.
    environment: str = "development"

    database_url: str = "postgresql://healthtracker:password@localhost:5432/healthtracker"
    jwt_secret: str = "your_jwt_secret_min_32_chars_long_key_here"
    n8n_webhook_url: str = "http://localhost:5678/webhook"

    # --- File storage (Phase 0: blobs out of Postgres) ---
    storage_backend: str = "local"          # "local" | "s3"
    storage_local_dir: str = "./storage"
    s3_bucket: str = ""
    s3_region: str = ""
    s3_endpoint_url: str = ""               # set for Supabase/R2/MinIO S3 endpoints
    s3_access_key_id: str = ""              # falls back to AWS_ACCESS_KEY_ID if empty
    s3_secret_access_key: str = ""          # falls back to AWS_SECRET_ACCESS_KEY if empty

    # --- Error monitoring ---
    sentry_dsn: str = ""                    # empty = disabled

    # --- Web Push (medicine reminders that fire when the app is closed) ---
    # Generate a keypair once with:  ./.venv/bin/vapid --gen  (py-vapid) or
    # `npx web-push generate-vapid-keys`. Leave blank to disable push entirely
    # (the in-app alarm keeps working regardless).
    vapid_public_key: str = ""
    vapid_private_key: str = ""
    vapid_subject: str = "mailto:admin@medistore.app"  # contact for push services

    # --- Firebase Cloud Messaging (mobile push) ---
    # Path to the Firebase service account JSON key file. Leave blank to
    # disable FCM delivery (mobile reminders fall back to local-only).
    firebase_service_account_path: str = ""

    # Shared secret that lets an external scheduler drive the reminder tick via
    # POST /api/push/run-tick (X-Cron-Secret header). On a free host that sleeps,
    # a 1-min cron hitting this endpoint both WAKES the instance and delivers due
    # reminders. Leave blank to disable the endpoint entirely (returns 404).
    cron_secret: str = ""

    # --- CORS ---
    # Comma-separated list of allowed origins. "*" allowed only in development.
    cors_origins: str = ""

    # --- Outbound email (password reset) ---
    # Two transports, tried in this order (see app/core/email.py):
    #
    #  1. Brevo HTTP API — talks HTTPS on 443. REQUIRED on Render's free plan,
    #     which blocks outbound SMTP ports 25/465/587 entirely, so an SMTP send
    #     there can only ever time out:
    #     https://render.com/changelog/free-web-services-will-no-longer-allow-outbound-traffic-to-smtp-ports
    #  2. Plain SMTP — fine locally and on paid hosts.
    #
    # With neither configured the email is logged instead of sent, so the flow
    # stays testable locally without a mail account.
    brevo_api_key: str = ""
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    # Sender identity for both transports. The address must be one the provider
    # has verified, or the send is rejected.
    smtp_from: str = "MediStore <no-reply@medistore.app>"

    # Base URL of the deployed frontend, used to build password-reset links.
    frontend_url: str = "http://localhost:3000"

    # --- Caretaker ---
    # Lets a patient grant another user account reminder delivery and medicine
    # read/write via a short-lived code. Off by default so the backend can ship
    # ahead of the UI; the care endpoints 404 while disabled and the reminder
    # fan-out collapses to patient-only (i.e. exactly the previous behaviour).
    caretaker_enabled: bool = False

    # --- Appointments ---
    # When true, a booking with a doctor is created PENDING and the doctor
    # accepts or rejects it; when false (the default) it is CONFIRMED on the
    # doctor's behalf, exactly as today. Surfaced on /health so a flag flip on
    # the running service is one curl away.
    doctor_confirms_bookings: bool = False

    class Config:
        env_file = ".env"

    @property
    def is_production(self) -> bool:
        return self.environment.lower() == "production"

    @property
    def push_enabled(self) -> bool:
        return bool(self.vapid_public_key and self.vapid_private_key)

    @property
    def email_enabled(self) -> bool:
        return bool(self.brevo_api_key or self.smtp_host)

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip():
            return [o.strip() for o in self.cors_origins.split(",") if o.strip()]
        if not self.is_production:
            return ["http://localhost:3000", "http://127.0.0.1:3000"]
        return []


# Sentinel values that must never survive into production.
_INSECURE_DEFAULTS = {
    "jwt_secret": "your_jwt_secret_min_32_chars_long_key_here",
}


def _validate_secrets(s: Settings) -> None:
    """Fail fast in production if secrets are missing or left at their defaults.

    Keeps real secrets out of source: the app reads them from the environment /
    .env only, and won't start a production process with placeholder values.
    """
    if not s.is_production:
        return

    problems = []
    for field, insecure in _INSECURE_DEFAULTS.items():
        value = getattr(s, field)
        if not value or value == insecure:
            problems.append(f"{field.upper()} is unset or using the insecure default")
    if len(s.jwt_secret) < 32:
        problems.append("JWT_SECRET must be at least 32 characters")
    if s.cors_origins.strip() == "*":
        problems.append("CORS_ORIGINS must be an explicit allowlist in production (not '*')")

    if problems:
        raise RuntimeError(
            "Insecure production configuration:\n  - "
            + "\n  - ".join(problems)
            + "\nSet these via environment variables / secret manager before deploying."
        )


settings = Settings()
_validate_secrets(settings)

# pool_pre_ping: test a pooled connection with a lightweight ping before use
#   and transparently replace it if the DB dropped it while idle. Without this
#   the API 500s ("offline") on the first request after an idle period because
#   it hands out a stale/closed connection.
# pool_recycle: proactively retire connections older than 280s so they never
#   outlive Postgres/OS idle timeouts in the first place.
engine = create_engine(
    settings.database_url,
    echo=False,
    pool_pre_ping=True,
    pool_recycle=280,
)


def get_session():
    with Session(engine) as session:
        yield session