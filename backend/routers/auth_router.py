"""FastAPI auth router — proxies Neon Auth (Better Auth) and handles
JWT validation for protected routes.

Routes:
  POST /auth/sign-up/email   → proxied to Better Auth
  POST /auth/sign-in/email   → proxied to Better Auth
  POST /auth/sign-out        → proxied to Better Auth
  POST /auth/refresh-token   → proxied to Better Auth
  POST /auth/forget-password → proxied to Better Auth
  GET  /auth/me              → current user from neon_auth.user

JWT validation is done via JWKS from Neon Auth.
Call `require_auth` as a dependency on any protected route.
"""

import os
import logging
from typing import Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from pydantic import BaseModel

logger = logging.getLogger(__name__)

BETTER_AUTH_URL = os.getenv("BETTER_AUTH_URL", "")
JWKS_URL = os.getenv("JWKS_URL", f"{BETTER_AUTH_URL}/api/auth/jwks")

router = APIRouter(prefix="/auth", tags=["auth"])
bearer_scheme = HTTPBearer(auto_error=False)

# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class UserProfile(BaseModel):
    id: str
    email: str
    name: Optional[str] = None
    image: Optional[str] = None
    email_verified: bool = False


# ---------------------------------------------------------------------------
# JWKS-based JWT validation
# ---------------------------------------------------------------------------

_jwks_cache: Optional[dict] = None

async def _get_jwks() -> dict:
    global _jwks_cache
    if _jwks_cache is None:
        async with httpx.AsyncClient() as client:
            resp = await client.get(JWKS_URL)
            resp.raise_for_status()
            _jwks_cache = resp.json()
    return _jwks_cache


async def require_auth(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
) -> dict:
    """Dependency: validate JWT and return decoded payload."""
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = credentials.credentials
    try:
        jwks = await _get_jwks()
        payload = jwt.decode(
            token,
            jwks,
            algorithms=["RS256"],
            options={"verify_aud": False},
        )
        return payload
    except JWTError as e:
        logger.warning("JWT validation failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ---------------------------------------------------------------------------
# Proxy helpers
# ---------------------------------------------------------------------------

async def _proxy_post(path: str, request: Request) -> dict:
    """Forward a POST request body to Better Auth and return its JSON response."""
    body = await request.body()
    headers = {
        "Content-Type": "application/json",
        "Authorization": request.headers.get("Authorization", ""),
    }
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{BETTER_AUTH_URL}{path}",
            content=body,
            headers=headers,
            timeout=15.0,
        )
    try:
        return resp.json()
    except Exception:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)


# ---------------------------------------------------------------------------
# Auth Routes
# ---------------------------------------------------------------------------

@router.post("/sign-up/email")
async def sign_up(request: Request):
    """Proxy signup to Neon Auth and sync user to public.users."""
    result = await _proxy_post("/api/auth/sign-up/email", request)
    if "user" in result and "id" in result["user"]:
        await _sync_user_to_public(result["user"])
    return result


@router.post("/sign-in/email")
async def sign_in(request: Request):
    """Proxy sign-in to Neon Auth."""
    result = await _proxy_post("/api/auth/sign-in/email", request)
    if "user" in result and "id" in result["user"]:
        await _sync_user_to_public(result["user"])
    return result


@router.post("/sign-out")
async def sign_out(request: Request):
    return await _proxy_post("/api/auth/sign-out", request)


@router.post("/refresh-token")
async def refresh_token(request: Request):
    return await _proxy_post("/api/auth/refresh-token", request)


@router.post("/forget-password")
async def forget_password(request: Request):
    return await _proxy_post("/api/auth/forget-password", request)


@router.get("/me", response_model=UserProfile)
async def get_current_user(
    payload: dict = Depends(require_auth),
) -> UserProfile:
    """Return current user profile from JWT payload."""
    return UserProfile(
        id=payload.get("sub", ""),
        email=payload.get("email", ""),
        name=payload.get("name"),
        image=payload.get("picture"),
        email_verified=payload.get("emailVerified", False),
    )


# ---------------------------------------------------------------------------
# User sync: neon_auth.user → public.users (upsert on first login)
# ---------------------------------------------------------------------------

async def _sync_user_to_public(user_data: dict) -> None:
    """Upsert neon_auth user into public.users table."""
    try:
        from ..database import get_db_connection  # local import to avoid circular
        async with get_db_connection() as conn:
            await conn.execute(
                """
                INSERT INTO public.users (id, email, name, created_at, updated_at)
                VALUES ($1, $2, $3, NOW(), NOW())
                ON CONFLICT (id) DO UPDATE
                  SET email = EXCLUDED.email,
                      name  = EXCLUDED.name,
                      updated_at = NOW()
                """,
                user_data["id"],
                user_data["email"],
                user_data.get("name"),
            )
    except Exception as e:
        logger.error("Failed to sync user to public.users: %s", e)
