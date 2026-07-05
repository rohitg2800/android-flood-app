# routers/predict.py
# Closes #47 — ML Flood Prediction API
import joblib
import numpy as np
from pathlib import Path
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, Query, Depends
from pydantic import BaseModel, field_validator
from app.db import get_db_session

router = APIRouter()

# ── Model registry ────────────────────────────────────────────────────────────
_MODEL = None
_MODEL_VERSION = "unknown"
_MODEL_PATH = Path("models/model.joblib")


def load_model() -> bool:
    """Load Random Forest model from disk. Returns True on success."""
    global _MODEL, _MODEL_VERSION
    if not _MODEL_PATH.exists():
        return False
    _MODEL = joblib.load(_MODEL_PATH)
    # Use file mtime last 8 digits as lightweight version tag
    _MODEL_VERSION = str(int(_MODEL_PATH.stat().st_mtime))[-8:]
    return True


def startup_load_model():
    """Call this in main.py @app.on_event('startup')."""
    ok = load_model()
    if ok:
        print(f"✅ Model loaded: version={_MODEL_VERSION}, "
              f"n_features={getattr(_MODEL, 'n_features_in_', '?')}")
    else:
        print("⚠️  models/model.joblib not found — POST /predict will return 503")


# ── Pydantic schemas ──────────────────────────────────────────────────────────
class PredictRequest(BaseModel):
    station_name: str
    state_name: str
    city_name: str | None = None
    # Feature vector: [peak_level_m, rainfall_total_mm, ...model features]
    features: list[float]

    @field_validator("features")
    @classmethod
    def check_features_non_empty(cls, v: list[float]) -> list[float]:
        if len(v) == 0:
            raise ValueError("features list must not be empty")
        return v


class PredictResponse(BaseModel):
    station_name: str
    severity: str
    confidence_percent: float
    risk_score: int
    model_version: str
    algorithm: str
    predicted_at: str


# ── Helpers ───────────────────────────────────────────────────────────────────
def _severity_from_prob(prob: float) -> tuple[str, int]:
    """Map flood probability (0–1) to severity label and risk score (0–100)."""
    if prob >= 0.80:
        return "Critical", 90
    if prob >= 0.60:
        return "High", 70
    if prob >= 0.40:
        return "Moderate", 50
    if prob >= 0.20:
        return "Low", 25
    return "Minimal", 5


# ── Endpoints ─────────────────────────────────────────────────────────────────
@router.post("/predict", response_model=PredictResponse)
async def predict(body: PredictRequest):
    """
    Run flood prediction inference and persist result to predictions table.

    Accepts:
        station_name, state_name, city_name, features: list[float]

    Returns:
        severity, confidence_percent, risk_score, model_version, predicted_at

    Errors:
        503 — model not loaded
        422 — wrong number of features
    """
    if _MODEL is None:
        raise HTTPException(
            status_code=503,
            detail="Model not loaded. Check GET /health/model for status.",
        )

    n_expected = _MODEL.n_features_in_
    if len(body.features) != n_expected:
        raise HTTPException(
            status_code=422,
            detail=f"Expected {n_expected} features, got {len(body.features)}.",
        )

    # Run inference
    X = np.array(body.features, dtype=np.float32).reshape(1, -1)
    prob = float(_MODEL.predict_proba(X)[0][1])  # P(flood=1)
    severity, risk_score = _severity_from_prob(prob)
    confidence_pct = round(prob * 100, 2)
    now = datetime.now(timezone.utc)

    # Persist to predictions table (schema: equinox-bh / neondb)
    async with get_db_session() as db:
        await db.execute(
            """
            INSERT INTO predictions (
                state_name, city_name, station_name,
                peak_level_m, rainfall_total_mm,
                severity, confidence_percent, risk_score,
                model_version, algorithm,
                input_payload, prediction_payload,
                created_at
            ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
            """,
            body.state_name,
            body.city_name,
            body.station_name,
            body.features[0] if len(body.features) > 0 else 0.0,  # peak_level_m
            body.features[1] if len(body.features) > 1 else 0.0,  # rainfall_total_mm
            severity,
            confidence_pct,
            risk_score,
            _MODEL_VERSION,
            "RandomForest",
            {"features": body.features},       # input_payload JSONB
            {"flood_probability": prob},        # prediction_payload JSONB
            now,
        )

    return PredictResponse(
        station_name=body.station_name,
        severity=severity,
        confidence_percent=confidence_pct,
        risk_score=risk_score,
        model_version=_MODEL_VERSION,
        algorithm="RandomForest",
        predicted_at=now.isoformat(),
    )


@router.get("/predict/latest")
async def latest_prediction(station_name: str = Query(...)):
    """
    Fetch the most recent prediction row for a given station.
    Uses idx_predictions_station_created index.
    """
    async with get_db_session() as db:
        row = await db.fetchrow(
            """
            SELECT station_name, severity, confidence_percent, risk_score,
                   model_version, algorithm, created_at
            FROM predictions
            WHERE station_name = $1
            ORDER BY created_at DESC
            LIMIT 1
            """,
            station_name,
        )
    if not row:
        raise HTTPException(
            status_code=404,
            detail=f"No predictions found for station '{station_name}'.",
        )
    result = dict(row)
    if hasattr(result.get("created_at"), "isoformat"):
        result["created_at"] = result["created_at"].isoformat()
    return result


@router.get("/health/model")
async def model_health():
    """Returns model load status, version, and feature count."""
    return {
        "loaded": _MODEL is not None,
        "version": _MODEL_VERSION,
        "n_features": getattr(_MODEL, "n_features_in_", None),
        "algorithm": "RandomForest",
        "model_path": str(_MODEL_PATH),
    }
