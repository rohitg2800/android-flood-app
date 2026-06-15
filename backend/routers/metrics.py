"""
backend/routers/metrics.py — OpsFlood /metrics API Router (Priority 3)

Endpoints:
    GET  /metrics           → latest persisted metrics from artifacts/metrics/ or Postgres
    GET  /metrics/live      → run evaluate_and_log_metrics on current test split (live)
    GET  /metrics/bootstrap → returns bootstrap_meta.json if bootstrap model was used

Wired in: backend/routers/__init__.py
"""

from __future__ import annotations

import json
import pickle
from pathlib import Path
from typing import Any, Dict, Optional

from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/metrics", tags=["ML Metrics"])

# ── Paths ─────────────────────────────────────────────────────────────────────
_BACKEND_ROOT = Path(__file__).parent.parent
METRICS_DIR   = _BACKEND_ROOT.parent / "artifacts" / "metrics"
MODEL_PATH    = _BACKEND_ROOT / "ml" / "saved_models" / "flood_model.pkl"
SCALER_PATH   = _BACKEND_ROOT / "ml" / "scalers" / "scaler.pkl"
BOOT_META     = _BACKEND_ROOT / "ml" / "saved_models" / "bootstrap_meta.json"


def _load_latest_metrics_from_disk() -> Optional[Dict[str, Any]]:
    """Read the most recently modified *_metrics.json from artifacts/metrics/."""
    if not METRICS_DIR.exists():
        return None
    files = sorted(METRICS_DIR.glob("*_metrics.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not files:
        return None
    with open(files[0]) as f:
        data = json.load(f)
    data["_source_file"] = files[0].name
    return data


def _load_latest_metrics_from_postgres() -> Optional[Dict[str, Any]]:
    """Try to fetch the most recent row from model_metrics table."""
    try:
        from backend.postgres_store import PostgresOperationalStore
        store = PostgresOperationalStore()
        store.initialize()
        if not store.ready:
            return None
        with store.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT model_name, recorded_at, weighted_f1, macro_f1,
                           macro_auroc, n_train, n_test, raw_json
                    FROM model_metrics
                    ORDER BY recorded_at DESC
                    LIMIT 1
                    """
                )
                row = cur.fetchone()
        if not row:
            return None
        cols = ["model_name", "recorded_at", "weighted_f1", "macro_f1",
                "macro_auroc", "n_train", "n_test", "raw_json"]
        result = dict(zip(cols, row))
        if result.get("recorded_at"):
            result["recorded_at"] = str(result["recorded_at"])
        if isinstance(result.get("raw_json"), str):
            result["raw_json"] = json.loads(result["raw_json"])
        result["_source"] = "postgres"
        return result
    except Exception as e:
        return None


@router.get("", summary="Latest persisted model metrics")
async def get_metrics() -> Dict[str, Any]:
    """
    Returns the latest saved model evaluation metrics.
    Priority: Postgres model_metrics table → artifacts/metrics/*.json → bootstrap_meta.json
    """
    # 1. Try Postgres
    pg = _load_latest_metrics_from_postgres()
    if pg:
        return pg

    # 2. Try disk JSON
    disk = _load_latest_metrics_from_disk()
    if disk:
        disk["_source"] = "disk"
        return disk

    # 3. Fallback: bootstrap metadata (synthetic training, not real test eval)
    if BOOT_META.exists():
        with open(BOOT_META) as f:
            meta = json.load(f)
        meta["_source"] = "bootstrap_synthetic"
        meta["_warning"] = (
            "These metrics are from synthetic CWC-calibrated bootstrap training. "
            "Train on real CWC data and call /metrics/live for validated scores."
        )
        return meta

    raise HTTPException(
        status_code=404,
        detail=(
            "No model metrics found. Run training via backend/train.py or "
            "POST /predict to trigger bootstrap, then call /metrics/live."
        ),
    )


@router.get("/live", summary="Run live model evaluation on current test split")
async def get_live_metrics() -> Dict[str, Any]:
    """
    Loads the saved model + scaler, generates a fresh test split from bootstrap data,
    runs evaluate_and_log_metrics, persists result, and returns the scores.
    Useful after retraining to immediately validate the new model.
    """
    if not MODEL_PATH.exists():
        raise HTTPException(
            status_code=503,
            detail="Model not found. Bootstrap will run on next startup, or run backend/ml/bootstrap_model.py manually.",
        )
    if not SCALER_PATH.exists():
        raise HTTPException(status_code=503, detail="Scaler not found.")

    try:
        with open(MODEL_PATH, "rb") as f:
            model = pickle.load(f)
        with open(SCALER_PATH, "rb") as f:
            scaler = pickle.load(f)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to load model artifacts: {e}")

    # Generate a reproducible test set using bootstrap generator
    try:
        import numpy as np
        from backend.ml.bootstrap_model import _generate_dataset
        X, y = _generate_dataset()
        split = int(0.8 * len(X))
        X_test, y_test = X[split:], y[split:]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Dataset generation failed: {e}")

    try:
        from backend.model_metrics import evaluate_and_log_metrics
        metrics = evaluate_and_log_metrics(
            model=model,
            scaler=scaler,
            X_test=X_test,
            y_test=y_test,
            model_name="flood_model_live",
        )
        metrics["_source"] = "live_evaluation"
        return metrics
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Evaluation failed: {e}")


@router.get("/bootstrap", summary="Bootstrap model metadata")
async def get_bootstrap_meta() -> Dict[str, Any]:
    """
    Returns metadata about the bootstrap synthetic model if present.
    Shows training accuracy, weighted F1, model type, and feature list.
    """
    if not BOOT_META.exists():
        raise HTTPException(
            status_code=404,
            detail="Bootstrap metadata not found. Model has not been bootstrapped yet.",
        )
    with open(BOOT_META) as f:
        meta = json.load(f)
    meta["model_path"] = str(MODEL_PATH)
    meta["scaler_path"] = str(SCALER_PATH)
    meta["model_exists"] = MODEL_PATH.exists()
    meta["scaler_exists"] = SCALER_PATH.exists()
    return meta
