"""Shared rate limiter (slowapi).

Keyed by client IP. Used to blunt brute-force attempts against auth endpoints.
The limiter is created here so routers and main.py share one instance.
"""

from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address

# Default limits apply to any route that opts in via @limiter.limit(...).
limiter = Limiter(key_func=get_remote_address)


def user_key(request: Request) -> str:
    """Rate-limit key identifying the caller, not their network.

    IP alone is the wrong bucket for the care-invite endpoints: a household or
    clinic behind one NAT shares an address, and an attacker can rotate
    addresses freely. The token's `sub` claim is read without a database hit —
    the route's own get_current_user dependency is what actually authenticates.
    Falls back to the peer address for unauthenticated or malformed requests.
    """
    auth = request.headers.get("authorization") or ""
    scheme, _, token = auth.partition(" ")
    if scheme.lower() == "bearer" and token:
        try:
            from jose import jwt

            from app.core.config import settings

            payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
            sub = payload.get("sub")
            if sub:
                return f"user:{sub}"
        except Exception:
            pass
    return f"ip:{get_remote_address(request)}"