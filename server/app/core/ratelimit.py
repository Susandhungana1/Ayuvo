"""Shared rate limiter (slowapi).

Keyed by client IP. Used to blunt brute-force attempts against auth endpoints.
The limiter is created here so routers and main.py share one instance.
"""

from slowapi import Limiter
from slowapi.util import get_remote_address

# Default limits apply to any route that opts in via @limiter.limit(...).
limiter = Limiter(key_func=get_remote_address)