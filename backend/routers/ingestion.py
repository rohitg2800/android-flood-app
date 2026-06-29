"""
Ingestion router: Data pipeline status, scheduling, and pipeline feature endpoints.

Endpoints:
  GET  /ingestion/status          - Scheduler + pipeline health
  POST /ingestion/run             - Trigger ingestion immediately
  GET  /api/pipeline/features     - Latest computed features (used by /predict/v2 & Flutter)
  GET  /api/pipeline/manifest     - Last run summary manifest
  GET  /api/state-severity        - Full state severity matrix (single source of truth)
  GET  /api/state-severity/{name} - Per-state severity entry
"""

import asyncio
from fastapi import APIRouter, HTTPException, Query

from .dependencies import (
    current_timestamp_iso,
    get_pipeline_features,
    get_pipeline_manifest,
    STATE_SEVERITY_MATRIX,
    get_state_severity_entry,
)

router = APIRouter(tags=["ingestion"])


# ── Scheduler health ────────────────────────────────────────────────────────

@router.get("/ingestion/status")
async def get_ingestion_status(
    data_pipeline=None,
    data_ingestion_scheduler=None,
):
    """Get data ingestion scheduler + pipeline status."""
    manifest = get_pipeline_manifest()
    return {
        "status": "success",
        "scheduler": data_ingestion_scheduler.status() if data_ingestion_scheduler else {},
        "last_manifest": manifest,
        "time": current_timestamp_iso(),
    }


@router.post("/ingestion/run")
async def run_ingestion_now(
    data_pipeline=None,
    data_ingestion_scheduler=None,
):
    """Trigger data ingestion immediately."""
    if not data_ingestion_scheduler:
        return {
            "status": "error",
            "result": {"status": "scheduler_not_available"},
            "time": current_timestamp_iso(),
        }

    result = await asyncio.to_thread(data_ingestion_scheduler.trigger_now)
    return {
        "status": "success" if result.get("status") == "success" else result.get("status"),
        "result": result,
        "time": current_timestamp_iso(),
    }


# ── Pipeline feature endpoints (the missing bridge) ─────────────────────────

@router.get("/api/pipeline/features")
async def get_pipeline_feature_row(
    state: str = Query(default="Bihar", description="State name (e.g. Maharashtra)"),
    station: str | None = Query(default=None, description="Optional station name"),
):
    """
    Return the latest OperationalDataPipeline feature row for a state/station.

    This is the single source of truth used by:
    - /predict/v2  (auto-fill defaults)
    - Flutter android-flood-app (pre-fill prediction form, show real-time stress index)

    Response fields:
      state_name, requested_station_name, river_level_m, warning_level_m,
      danger_level_m, rainfall_1h_mm, rainfall_3h_mm, rainfall_last_hour_mm,
      humidity_pct, pressure_hpa, temperature_c, warning_headroom_m,
      danger_headroom_m, hydro_meteorological_stress_index, feature_ready_at
    """
    features = get_pipeline_features(state, station)
    if features is None:
        raise HTTPException(
            status_code=404,
            detail=(
                f"No pipeline features available for state='{state}'"
                f"{', station=' + repr(station) if station else ''}. "
                "Trigger POST /ingestion/run to populate."
            ),
        )
    return {
        "status": "success",
        "source": "OperationalDataPipeline",
        "data": features,
        "time": current_timestamp_iso(),
    }


@router.get("/api/pipeline/manifest")
async def get_pipeline_manifest_endpoint():
    """Return the last ingestion run summary."""
    manifest = get_pipeline_manifest()
    if manifest is None:
        raise HTTPException(
            status_code=404,
            detail="No ingestion manifest found. Run POST /ingestion/run first.",
        )
    return {
        "status": "success",
        "manifest": manifest,
        "time": current_timestamp_iso(),
    }


# ── State severity matrix (single source of truth for Flutter) ──────────────

@router.get("/api/state-severity")
async def get_state_severity_all():
    """
    Return the full STATE_SEVERITY_MATRIX as JSON.

    Flutter android-flood-app must call this endpoint instead of maintaining
    a hardcoded Dart copy. Call once at app startup and cache locally.
    """
    return {
        "status": "success",
        "source": "state_severity_matrix.py",
        "count": len(STATE_SEVERITY_MATRIX),
        "matrix": STATE_SEVERITY_MATRIX,
        "time": current_timestamp_iso(),
    }


@router.get("/api/state-severity/{state_name}")
async def get_state_severity_one(state_name: str):
    """
    Return the severity entry for a single state.
    Returns a 200 with the default entry if state is unknown (never 404).
    """
    entry = get_state_severity_entry(state_name)
    return {
        "status": "success",
        "state": state_name,
        "entry": entry,
        "in_matrix": state_name in STATE_SEVERITY_MATRIX,
        "time": current_timestamp_iso(),
    }
