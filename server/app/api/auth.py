from datetime import datetime, timedelta
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel, field_validator
from sqlmodel import Session, select

from app.core.config import settings, get_session
from app.core.ratelimit import limiter
from app.core.audit import record_access
from app.models.models import User

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