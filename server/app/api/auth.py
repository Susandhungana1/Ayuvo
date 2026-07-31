import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel, field_validator
from sqlmodel import Session, select

from app.core.config import settings, get_session
from app.core.email import send_email
from app.core.ratelimit import limiter
from app.core.audit import record_access
from app.models.models import User, PasswordResetToken

router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


class UserCreate(BaseModel):
    name: str
    email: str
    password: str

    @field_validator('password')
    @classmethod
    def password_min_length(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        return v

    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        import re
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(pattern, v):
            raise ValueError('Invalid email format')
        return v.lower()


class UserResponse(BaseModel):
    id: str
    name: str
    email: str
    role: str


class TokenResponse(BaseModel):
    id: str
    name: str
    email: str
    role: str
    token: str


class LoginChallengeResponse(BaseModel):
    """Returned when credentials are valid but 2FA is enabled and no/învalid
    TOTP code was supplied. The client should prompt for the code and resubmit."""
    totp_required: bool = True


class TotpEnableResponse(BaseModel):
    secret: str
    otpauth_url: str
    qr_code_data_uri: str


class TotpVerifyRequest(BaseModel):
    code: str


class TotpStatusResponse(BaseModel):
    enabled: bool


class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

    @field_validator('new_password')
    @classmethod
    def password_min_length(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        return v


class MessageResponse(BaseModel):
    message: str


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(days=7))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.jwt_secret, algorithm="HS256")


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_session)
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = db.get(User, user_id)
    if user is None:
        raise credentials_exception
    return user


@router.post("/register", response_model=TokenResponse)
@limiter.limit("5/minute")
async def register(request: Request, user_data: UserCreate, db: Session = Depends(get_session)):
    existing = db.exec(select(User).where(User.email == user_data.email)).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    hashed_password = pwd_context.hash(user_data.password)
    user = User(
        name=user_data.name,
        email=user_data.email,
        password=hashed_password
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    
    token = create_access_token({"sub": user.id})
    return TokenResponse(
        id=user.id,
        name=user.name,
        email=user.email,
        role=user.role,
        token=token
    )


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(
    request: Request,
    form: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_session)
):
    user = db.exec(select(User).where(User.email == form.username)).first()
    if not user or not pwd_context.verify(form.password, user.password):
        record_access(db, "auth.login.failed", request=request, detail=form.username)
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # Second factor: OAuth2 password form has no TOTP field, so the client sends
    # the 6-digit code in the optional `client_secret` form field.
    if user.totp_enabled:
        code = (form.client_secret or "").strip()
        if not code:
            # Signal the client to collect a code and retry. 401 keeps it generic.
            raise HTTPException(
                status_code=401,
                detail="TOTP code required",
                headers={"X-2FA-Required": "true"},
            )
        if not _verify_totp(user.totp_secret, code):
            record_access(db, "auth.2fa.failed", actor_id=user.id, request=request)
            raise HTTPException(status_code=401, detail="Invalid TOTP code")

    record_access(db, "auth.login", actor_id=user.id, request=request)
    token = create_access_token({"sub": user.id})
    return TokenResponse(
        id=user.id,
        name=user.name,
        email=user.email,
        role=user.role,
        token=token
    )


# --- Password reset ---

RESET_TOKEN_TTL = timedelta(minutes=30)


def _hash_token(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()


@router.post("/forgot-password", response_model=MessageResponse)
@limiter.limit("3/minute")
async def forgot_password(
    request: Request,
    data: ForgotPasswordRequest,
    db: Session = Depends(get_session),
):
    """Start a password reset. Always answers the same way whether or not the
    email has an account, so this endpoint can't be used to enumerate users."""
    generic = MessageResponse(
        message="If an account exists for that email, a reset link has been sent."
    )

    user = db.exec(select(User).where(User.email == data.email.lower().strip())).first()
    if not user:
        record_access(db, "auth.reset.requested_unknown", request=request, detail=data.email)
        return generic

    # Invalidate any outstanding tokens so only the newest link works.
    for old in db.exec(
        select(PasswordResetToken).where(
            PasswordResetToken.user_id == user.id,
            PasswordResetToken.used == False,  # noqa: E712
        )
    ).all():
        old.used = True
        db.add(old)

    raw_token = secrets.token_urlsafe(32)
    db.add(PasswordResetToken(
        user_id=user.id,
        token_hash=_hash_token(raw_token),
        expires_at=datetime.utcnow() + RESET_TOKEN_TTL,
    ))
    db.commit()
    record_access(db, "auth.reset.requested", actor_id=user.id, request=request)

    base = settings.frontend_url.rstrip("/")
    reset_page = f"{base}/auth/reset-password"
    reset_link = f"{reset_page}?token={raw_token}"
    minutes = int(RESET_TOKEN_TTL.total_seconds() // 60)
    # The bare code is included as well as the link: mail clients sometimes
    # mangle or truncate long URLs, and the user may open the mail on a
    # different device, so the reset page also accepts a pasted code.
    sent = send_email(
        to=user.email,
        subject="Reset your MediStore password",
        text=(
            f"Hi {user.name},\n\n"
            f"We received a request to reset your MediStore password. "
            f"Open the link below to choose a new one (valid for {minutes} minutes):\n\n"
            f"{reset_link}\n\n"
            f"If the link doesn't work, open {reset_page} and paste this code:\n\n"
            f"{raw_token}\n\n"
            f"If you didn't request this, you can safely ignore this email — "
            f"your password will stay unchanged.\n"
        ),
        html=(
            f"<p>Hi {user.name},</p>"
            f"<p>We received a request to reset your MediStore password. "
            f"Click the button below to choose a new one (valid for {minutes} minutes):</p>"
            f'<p><a href="{reset_link}" style="display:inline-block;padding:10px 20px;'
            f'background:#2563eb;color:#fff;border-radius:8px;text-decoration:none">'
            f"Reset password</a></p>"
            f"<p>Or copy this link into your browser:<br>{reset_link}</p>"
            f'<p>If the link doesn\'t work, open <a href="{reset_page}">{reset_page}</a> '
            f"and paste this code:</p>"
            f'<p style="font-family:monospace;background:#f3f4f6;padding:10px 14px;'
            f'border-radius:6px;word-break:break-all">{raw_token}</p>'
            f"<p>If you didn't request this, you can safely ignore this email — "
            f"your password will stay unchanged.</p>"
        ),
    )
    if not sent:
        # The client still gets the generic answer — telling it the send failed
        # would leak that the account exists. Record it here instead so a
        # broken mail provider shows up in the audit trail rather than only in
        # the host's logs, where it looks identical to "user never asked".
        record_access(db, "auth.reset.email_failed", actor_id=user.id, request=request)
    return generic


@router.post("/reset-password", response_model=MessageResponse)
@limiter.limit("5/minute")
async def reset_password(
    request: Request,
    data: ResetPasswordRequest,
    db: Session = Depends(get_session),
):
    """Complete a password reset with a token from the email link."""
    token = db.exec(
        select(PasswordResetToken).where(
            PasswordResetToken.token_hash == _hash_token(data.token)
        )
    ).first()

    if not token or token.used or token.expires_at < datetime.utcnow():
        record_access(db, "auth.reset.invalid_token", request=request)
        raise HTTPException(
            status_code=400,
            detail="This reset link is invalid or has expired. Please request a new one.",
        )

    user = db.get(User, token.user_id)
    if not user:
        raise HTTPException(status_code=400, detail="Invalid reset link")

    user.password = pwd_context.hash(data.new_password)
    user.updated_at = datetime.utcnow()
    token.used = True
    db.add(user)
    db.add(token)
    db.commit()
    record_access(db, "auth.reset.completed", actor_id=user.id, request=request)

    return MessageResponse(message="Password updated. You can now sign in with your new password.")


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return UserResponse(
        id=current_user.id,
        name=current_user.name,
        email=current_user.email,
        role=current_user.role
    )


# --- Two-factor auth (TOTP) ---

def _verify_totp(secret: Optional[str], code: str) -> bool:
    if not secret:
        return False
    import pyotp
    # valid_window=1 tolerates ~30s clock drift between server and phone.
    return pyotp.TOTP(secret).verify(code, valid_window=1)


@router.get("/2fa/status", response_model=TotpStatusResponse)
async def totp_status(current_user: User = Depends(get_current_user)):
    return TotpStatusResponse(enabled=current_user.totp_enabled)


@router.post("/2fa/setup", response_model=TotpEnableResponse)
async def totp_setup(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Generate a fresh TOTP secret and provisioning QR. 2FA is not active until
    the user confirms a code via /2fa/verify, so a failed setup can't lock them out."""
    if current_user.totp_enabled:
        raise HTTPException(status_code=400, detail="2FA already enabled")

    import base64
    import io
    import pyotp
    import qrcode

    secret = pyotp.random_base32()
    otpauth_url = pyotp.TOTP(secret).provisioning_uri(
        name=current_user.email, issuer_name="MediStore"
    )

    img = qrcode.make(otpauth_url)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    qr_data_uri = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

    # Store the secret but keep totp_enabled False until verified.
    current_user.totp_secret = secret
    current_user.updated_at = datetime.utcnow()
    db.add(current_user)
    db.commit()

    return TotpEnableResponse(
        secret=secret, otpauth_url=otpauth_url, qr_code_data_uri=qr_data_uri
    )


@router.post("/2fa/verify", response_model=TotpStatusResponse)
async def totp_verify(
    data: TotpVerifyRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Confirm the code from the authenticator app to activate 2FA."""
    if not current_user.totp_secret:
        raise HTTPException(status_code=400, detail="Run /2fa/setup first")
    if not _verify_totp(current_user.totp_secret, data.code.strip()):
        raise HTTPException(status_code=400, detail="Invalid code")

    current_user.totp_enabled = True
    current_user.updated_at = datetime.utcnow()
    db.add(current_user)
    db.commit()
    record_access(db, "auth.2fa.enabled", actor_id=current_user.id, request=request)
    return TotpStatusResponse(enabled=True)


@router.post("/2fa/disable", response_model=TotpStatusResponse)
async def totp_disable(
    data: TotpVerifyRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Disable 2FA. Requires a valid current code so a stolen session token alone
    can't turn it off."""
    if not current_user.totp_enabled:
        return TotpStatusResponse(enabled=False)
    if not _verify_totp(current_user.totp_secret, data.code.strip()):
        raise HTTPException(status_code=400, detail="Invalid code")

    current_user.totp_enabled = False
    current_user.totp_secret = None
    current_user.updated_at = datetime.utcnow()
    db.add(current_user)
    db.commit()
    record_access(db, "auth.2fa.disabled", actor_id=current_user.id, request=request)
    return TotpStatusResponse(enabled=False)