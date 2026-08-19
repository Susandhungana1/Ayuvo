"""Shared rate limiter (slowapi).

Keyed by client IP. Used to blunt brute-force attempts against auth endpoints.
The limiter is created here so routers and main.py share one instance.
"""

from ipaddress import ip_address
from typing import Optional

from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address


def client_ip(request: Request) -> Optional[str]:
    """Best-effort stable client IP.

    `request.client.host` is the peer address — on Render the request arrives
    via a Cloudflare-backed edge, so the peer rotates across anycast IPs and a
    per-peer rate-limit bucket never trips for a single real client. Prefer the
    identifiers the edge attaches instead:
      1. `CF-Connecting-IP` (set by Cloudflare for proxied traffic), else
      2. the first `X-Forwarded-For` hop (appended by the edge; CF overwrites
         the header, so a client-supplied value cannot pass through), else
      3. the socket peer.
    """
    forwarded = request.headers.get("cf-connecting-ip")
    if forwarded:
        return forwarded.strip()
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        first = forwarded.split(",")[0].strip()
        if first:
            try:
                ip_address(first)
            except ValueError:
                pass
            else:
                return first
    return get_remote_address(request)


def client_key(request: Request) -> str:
    """Rate-limit key that is stable per real client behind the edge."""
    return f"ip:{client_ip(request)}"


# Default limits apply to any route that opts in via @limiter.limit(...).
limiter = Limiter(key_func=client_key)


def user_key(request: Request) -> str:
    """Rate-limit key identifying the caller, not their network.

    IP alone is the wrong bucket for the care-invite endpoints: a household or
    clinic behind one NAT shares an address, and an attacker can rotate
    addresses freely. The token's `sub` claim is read without a database hit —
    the route's own get_current_user dependency is what actually authenticates.
    Falls back to the stable client key (see `client_key`) for unauthenticated
    or malformed requests.
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
    return client_key(request)