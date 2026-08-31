import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional, List
from fastapi import APIRouter, Depends, Form, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel, field_validator
from sqlmodel import Session, select

from app.core.config import settings, get_session
from app.core.email import send_email
from app.core.ratelimit import limiter
from app.core.audit import record_access
from app.core.time import utcnow
from app.models.models import User, PasswordResetToken, RefreshToken

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
    refresh_token: str


class RefreshRequest(BaseModel):
    refresh_token: str


class RefreshResponse(BaseModel):
    token: str
    refresh_token: str


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
    expire = utcnow() + (expires_delta or ACCESS_TOKEN_TTL)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.jwt_secret, algorithm="HS256")


# Access tokens are short-lived stateless JWTs; refresh tokens are long-lived
# opaque strings stored hashed in the DB so they can be revoked and rotated.
ACCESS_TOKEN_TTL = timedelta(minutes=60)
REFRESH_TOKEN_TTL = timedelta(days=30)
# A replayed refresh token that was rotated this recently is a sibling-tab
# race, not an attacker — reject without burning the family.
REPLAY_GRACE = timedelta(seconds=30)


def _issue_refresh_token(db: Session, user_id: str, replaced: Optional[RefreshToken] = None) -> str:
    """Create a refresh-token row and return the raw token. When `replaced` is
    given (rotation), the old row is revoked and linked to its successor."""
    raw = secrets.token_urlsafe(48)
    row = RefreshToken(
        user_id=user_id,
        token_hash=_hash_token(raw),
        expires_at=utcnow() + REFRESH_TOKEN_TTL,
    )
    db.add(row)
    db.flush()
    if replaced is not None:
        replaced.revoked_at = utcnow()
        replaced.replaced_by = row.token_hash
        db.add(replaced)
    db.commit()
    return raw


def _issue_session(db: Session, user: User) -> TokenResponse:
    token = create_access_token({"sub": user.id})
    refresh_token = _issue_refresh_token(db, user.id)
    return TokenResponse(
        id=user.id,
        name=user.name,
        email=user.email,
        role=user.role,
        token=token,
        refresh_token=refresh_token,
    )


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

    record_access(db, "auth.register", actor_id=user.id, request=request)
    return _issue_session(db, user)


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(
    request: Request,
    form: OAuth2PasswordRequestForm = Depends(),
    totp_code: Optional[str] = Form(None),
    db: Session = Depends(get_session)
):
    user = db.exec(select(User).where(User.email == form.username)).first()
    if not user or not pwd_context.verify(form.password, user.password):
        record_access(db, "auth.login.failed", request=request, detail=form.username)
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # Second factor: prefer explicit totp_code field or X-TOTP-Code header;
    # fall back to client_secret for backward compat with older clients.
    if user.totp_enabled:
        header_code = request.headers.get("X-TOTP-Code", "")
        code = (totp_code or header_code or form.client_secret or "").strip()
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
    return _issue_session(db, user)


@router.post("/refresh", response_model=RefreshResponse)
@limiter.limit("20/minute")
async def refresh(
    request: Request,
    data: RefreshRequest,
    db: Session = Depends(get_session),
):
    """Exchange a refresh token for a fresh access token, rotating the refresh
    token in the process.

    Presenting a token that has already been consumed is the signature of a
    stolen-token replay, so that revokes every outstanding refresh token for
    the user (the whole family) rather than just the one. The exception is a
    token rotated within `REPLAY_GRACE`: two tabs that expire together race
    the same refresh, and the loser looks exactly like a replay. That case
    only rejects the request, keeping the family alive.
    """
    token = db.exec(
        select(RefreshToken).where(
            RefreshToken.token_hash == _hash_token(data.refresh_token.strip())
        )
    ).first()

    if token is None:
        record_access(db, "auth.refresh.unknown", request=request)
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    if token.revoked_at is not None:
        # A token that was rotated moments ago was probably consumed by a
        # sibling tab, not an attacker: two tabs whose access tokens expire at
        # the same moment race the same refresh, and the loser replays the
        # token the winner just rotated. Within the grace window treat that as
        # a race — reject it, but leave the family alive so the legitimate
        # session survives. Only replays older than the window get the
        # burn-the-family response.
        if utcnow() - token.revoked_at < REPLAY_GRACE:
            record_access(
                db, "auth.refresh.race", actor_id=token.user_id,
                request=request, detail="revoked_token_within_grace",
            )
            raise HTTPException(status_code=401, detail="Invalid refresh token")
        # Genuine replay of an already-rotated token: burn the family.
        for member in db.exec(
            select(RefreshToken).where(RefreshToken.user_id == token.user_id)
        ).all():
            if member.revoked_at is None:
                member.revoked_at = utcnow()
                db.add(member)
        db.commit()
        record_access(
            db, "auth.refresh.replay", actor_id=token.user_id, request=request,
            detail="revoked_token_replayed",
        )
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    if token.expires_at < utcnow():
        record_access(db, "auth.refresh.expired", actor_id=token.user_id, request=request)
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user = db.get(User, token.user_id)
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    # Opportunistic cleanup: drop this user's long-expired rows.
    for old in db.exec(
        select(RefreshToken).where(
            RefreshToken.user_id == user.id,
            RefreshToken.expires_at < utcnow(),
        )
    ).all():
        db.delete(old)
    db.commit()

    new_refresh = _issue_refresh_token(db, user.id, replaced=token)
    record_access(db, "auth.refresh", actor_id=user.id, request=request)
    return RefreshResponse(
        token=create_access_token({"sub": user.id}),
        refresh_token=new_refresh,
    )


@router.post("/logout", response_model=MessageResponse)
async def logout(
    request: Request,
    data: Optional[RefreshRequest] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Revoke the presented refresh token so the session cannot come back.
    The access token stays valid until it expires on its own (short-lived)."""
    if data and data.refresh_token.strip():
        token = db.exec(
            select(RefreshToken).where(
                RefreshToken.token_hash == _hash_token(data.refresh_token.strip()),
                RefreshToken.user_id == current_user.id,
            )
        ).first()
        if token is not None and token.revoked_at is None:
            token.revoked_at = utcnow()
            db.add(token)
            db.commit()
            record_access(
                db, "auth.logout", actor_id=current_user.id, request=request,
                detail="refresh_revoked",
            )
    else:
        record_access(db, "auth.logout", actor_id=current_user.id, request=request)

    return MessageResponse(message="Signed out")


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
        expires_at=utcnow() + RESET_TOKEN_TTL,
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
    # The user controls their own name; escape it so it can't smuggle HTML
    # into their inbox (self-XSS) or break the email's markup.
    import html as _html
    name_html = _html.escape(user.name, quote=True)

    sent = send_email(
        to=user.email,
        subject="Reset your Ayuvo password",
        text=(
            f"Hi {user.name},\n"
            f"\n"
            f"We received a request to reset the password for your Ayuvo account.\n"
            f"Click the link below to choose a new password. This link is valid for\n"
            f"{minutes} minutes.\n"
            f"\n"
            f"  {reset_link}\n"
            f"\n"
            f"If the button above doesn't work, copy and paste the link into your\n"
            f"browser's address bar.\n"
            f"\n"
            f"Alternatively, open the reset page and paste this code:\n"
            f"\n"
            f"  Reset page:  {reset_page}\n"
            f"\n"
            f"{raw_token}\n"
            f"\n"
            f"If you didn't request a password reset, you can safely ignore this\n"
            f"email. Your password will remain unchanged.\n"
            f"\n"
            f"--\n"
            f"Ayuvo  |  Your Digital Health Store\n"
        ),
        html=(
            f"<!DOCTYPE html>"
            f"<html><head><meta charset=\"utf-8\"></head>"
            f"<body style=\"margin:0;padding:0;background:#f4f6f8;font-family:Arial,Helvetica,sans-serif;\">"
            f"<table width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"background:#f4f6f8;padding:40px 0;\">"
            f"<tr><td align=\"center\">"
            f"<table width=\"480\" cellpadding=\"0\" cellspacing=\"0\" style=\"background:#ffffff;"
            f"border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);\">"
            # Header
            f"<tr><td style=\"background:#1a56db;padding:28px 32px;text-align:center;\">"
            f"<h1 style=\"margin:0;color:#ffffff;font-size:20px;font-weight:700;letter-spacing:0.5px;\">"
            f"Ayuvo</h1>"
            f"<p style=\"margin:6px 0 0;color:#bfdbfe;font-size:13px;\">Your Digital Health Store</p>"
            f"</td></tr>"
            # Body
            f"<tr><td style=\"padding:36px 32px 24px;\">"
            f"<p style=\"margin:0 0 20px;color:#1f2937;font-size:16px;\">Hi {name_html},</p>"
            f"<p style=\"margin:0 0 20px;color:#4b5563;font-size:15px;line-height:1.6;\">"
            f"We received a request to reset the password for your Ayuvo account. "
            f"Click the button below to choose a new password.</p>"
            # Button
            f'<table cellpadding="0" cellspacing="0" style="margin:0 0 28px;"><tr>'
            f'<td><a href="{reset_link}" style="display:inline-block;padding:14px 32px;'
            f"background:#1a56db;color:#ffffff;font-size:15px;font-weight:600;"
            f'text-decoration:none;border-radius:8px;">Reset Password</a></td>'
            f"</tr></table>"
            # Expiry note
            f'<p style="margin:0 0 24px;color:#6b7280;font-size:13px;">'
            f"This link expires in <strong>{minutes} minutes</strong>.</p>"
            # Divider
            f'<table width="100%" cellpadding="0" cellspacing="0">'
            f'<tr><td style="border-top:1px solid #e5e7eb;"></td></tr></table>'
            # Fallback section
            f'<p style="margin:24px 0 12px;color:#4b5563;font-size:14px;line-height:1.6;">'
            f"If the button doesn't work, copy and paste this link into your browser:</p>"
            f'<p style="margin:0 0 20px;padding:10px 14px;background:#f9fafb;border:1px solid #e5e7eb;'
            f'border-radius:6px;word-break:break-all;font-family:monospace;font-size:13px;color:#374151;">'
            f"{reset_link}</p>"
            # Code section
            f'<p style="margin:0 0 8px;color:#4b5563;font-size:14px;line-height:1.6;">'
            f"Or open the reset page and paste this code:</p>"
            f'<table cellpadding="0" cellspacing="0" style="margin:0 0 24px;">'
            f'<tr><td style="padding:8px 14px;background:#f9fafb;border:1px solid #e5e7eb;border-radius:6px;'
            f'font-family:monospace;font-size:13px;color:#374151;word-break:break-all;">'
            f"{raw_token}</td></tr></table>"
            # Divider
            f'<table width="100%" cellpadding="0" cellspacing="0">'
            f'<tr><td style="border-top:1px solid #e5e7eb;"></td></tr></table>'
            # Ignore notice
            f'<p style="margin:24px 0 0;color:#6b7280;font-size:13px;line-height:1.5;">'
            f"If you didn't request a password reset, you can safely ignore this email. "
            f"Your password will remain unchanged.</p>"
            f"</td></tr>"
            # Footer
            f'<tr><td style="background:#f9fafb;padding:20px 32px;text-align:center;'
            f'border-top:1px solid #e5e7eb;">'
            f'<p style="margin:0;color:#9ca3af;font-size:12px;">'
            f"Ayuvo &mdash; Your Digital Health Store</p>"
            f"</td></tr>"
            f"</table>"
            f"</td></tr></table>"
            f"</body></html>"
        ),
    )
    if not sent:
        # The client still gets the generic answer — telling it the send failed
        # would leak that the account exists. Record it here instead so a
        # broken mail provider shows up in the audit trail rather than only in
        # the host's logs, where it looks identical to "user never asked".
        record_access(
            db, "auth.reset.email_failed", actor_id=user.id, request=request,
            detail=sent.error,
        )
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

    if not token or token.used or token.expires_at < utcnow():
        record_access(db, "auth.reset.invalid_token", request=request)
        raise HTTPException(
            status_code=400,
            detail="This reset link is invalid or has expired. Please request a new one.",
        )

    user = db.get(User, token.user_id)
    if not user:
        raise HTTPException(status_code=400, detail="Invalid reset link")

    user.password = pwd_context.hash(data.new_password)
    user.updated_at = utcnow()
    token.used = True
    db.add(user)
    db.add(token)

    # A password change must end every existing session: a stolen refresh
    # token would otherwise keep working for up to 30 days after the victim
    # resets their password. Revoke the whole family (same sweep the refresh
    # replay handler performs).
    members = db.exec(
        select(RefreshToken).where(
            RefreshToken.user_id == user.id,
            RefreshToken.revoked_at.is_(None),
        )
    ).all()
    for member in members:
        member.revoked_at = utcnow()
        db.add(member)

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
        name=current_user.email, issuer_name="Ayuvo"
    )

    img = qrcode.make(otpauth_url)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    qr_data_uri = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

    # Store the secret but keep totp_enabled False until verified.
    current_user.totp_secret = secret
    current_user.updated_at = utcnow()
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
    current_user.updated_at = utcnow()
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
    current_user.updated_at = utcnow()
    db.add(current_user)
    db.commit()
    record_access(db, "auth.2fa.disabled", actor_id=current_user.id, request=request)
    return TotpStatusResponse(enabled=False)


# ---------------------------------------------------------------------------
# Change password (signed-in user)
# ---------------------------------------------------------------------------

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def password_min_length(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


@router.post("/change-password")
@limiter.limit("5/minute")
async def change_password(
    request: Request,
    data: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_session),
):
    """Change the signed-in user's password. Requires the current password."""
    if not pwd_context.verify(data.current_password, current_user.password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    current_user.password = pwd_context.hash(data.new_password)
    current_user.updated_at = utcnow()
    db.add(current_user)
    db.commit()
    record_access(db, "auth.change_password", actor_id=current_user.id, request=request)
    return {"message": "Password updated"}