"""Phase 2 – Enhanced Accessibility Settings API routes."""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from db import get_db
from auth import get_current_user

router = APIRouter(prefix="/accessibility", tags=["Accessibility"])


# ── Schema ───────────────────────────────────────────────────────────────────

class AccessibilitySettingsUpdate(BaseModel):
    # Phase 1 fields
    text_scale: Optional[float] = None
    high_contrast: Optional[bool] = None
    bold_text: Optional[bool] = None
    locale: Optional[str] = None
    reduce_motion: Optional[bool] = None
    large_tap_targets: Optional[bool] = None
    screen_reader_mode: Optional[bool] = None
    color_blind_mode: Optional[str] = None
    # Phase 2 new fields
    font_family: Optional[str] = None
    line_spacing: Optional[float] = None
    focus_highlight: Optional[bool] = None
    captions_enabled: Optional[bool] = None
    haptic_feedback: Optional[bool] = None


# ── Routes ───────────────────────────────────────────────────────────────────

@router.get("/me")
async def get_my_accessibility(
    db=Depends(get_db),
    user=Depends(get_current_user),
):
    """Fetch the current user's accessibility settings."""
    row = await db.fetchrow(
        "SELECT * FROM user_accessibility_settings WHERE user_id=$1",
        user["id"],
    )
    if not row:
        # Return defaults if no record exists yet
        return {
            "user_id": user["id"],
            "text_scale": 1.0, "high_contrast": False, "bold_text": False,
            "locale": "en", "reduce_motion": False, "large_tap_targets": False,
            "screen_reader_mode": False, "color_blind_mode": "none",
            "font_family": "system", "line_spacing": 1.5,
            "focus_highlight": False, "captions_enabled": False,
            "haptic_feedback": False,
        }
    return dict(row)


@router.put("/me")
async def upsert_my_accessibility(
    payload: AccessibilitySettingsUpdate,
    db=Depends(get_db),
    user=Depends(get_current_user),
):
    """Create or update the current user's accessibility settings."""
    updates = {k: v for k, v in payload.dict().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")

    fields = ", ".join(f"{k}=${i+2}" for i, k in enumerate(updates))
    values = list(updates.values())

    row = await db.fetchrow(
        f"""
        INSERT INTO user_accessibility_settings (user_id, {', '.join(updates.keys())})
        VALUES ($1, {', '.join(f'${i+2}' for i in range(len(values)))})
        ON CONFLICT (user_id) DO UPDATE SET {fields}, updated_at = now()
        RETURNING *
        """,
        user["id"], *values,
    )
    return dict(row)
