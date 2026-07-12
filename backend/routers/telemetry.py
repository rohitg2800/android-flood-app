"""
Telemetry router: Live telemetry, audit logs, and CWC data endpoints.
"""

from fastapi import APIRouter
from typing import Any, Dict
import csv
import os

from .dependencies import (
    operational_store,
    persist_telemetry_record,
    get_source_policy_payload,
    BASE_DIR,
    REPO_DIR,
    current_timestamp_iso,
)

# ── Module-level CWC scraper singleton ────────────────────────────────────────────
# Import CWCRiverScraper here so the scraper is always initialized
# regardless of which endpoint is called first.
try:
    from backend.cwc_scraper import CWCRiverScraper
except ImportError:
    from cwc_scraper import CWCRiverScraper  # type: ignore

_cwc_scraper = CWCRiverScraper()

router = APIRouter(tags=["telemetry"])


def _normalize_log_key(value: str) -> str:
    value = (value or "").strip().lower()
    cleaned = "".join(ch if ch.isalnum() or ch.isspace() else " " for ch in value)
    return " ".join(cleaned.split())


def _safe_float(value: Any) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


# ============= PREDICTION HISTORY =============
@router.get("/prediction-history")
async def get_prediction_history(state: str | None = None, limit: int = 50):
    """Get recent prediction history."""
    records = operational_store.list_predictions(limit=limit, state_name=state)
    return {
        "status": "success",
        "storage": operational_store.status(),
        "total_records": len(records),
        "records": [
            {
                "id": record["id"],
                "timestamp": record["created_at"].isoformat() if record.get("created_at") else None,
                "state": record.get("state_name"),
                "city": record.get("city_name"),
                "station": record.get("station_name"),
                "peak_level": float(record.get("peak_level_m") or 0.0),
                "rainfall": float(record.get("rainfall_total_mm") or 0.0),
                "severity": record.get("severity"),
                "confidence": float(record.get("confidence_percent") or 0.0),
                "risk_score": record.get("risk_score"),
                "data_source": record.get("data_source"),
                "algorithm": record.get("algorithm"),
                "model_version": record.get("model_version"),
                "monitoring_level": record.get("monitoring_level"),
                "monitoring_action": record.get("monitoring_action"),
                "source_policy_mode": record.get("source_policy_mode"),
                "source_policy_label": record.get("source_policy_label"),
            }
            for record in records
        ],
    }


# ============= TELEMETRY SNAPSHOTS =============
@router.get("/telemetry-snapshots")
async def get_telemetry_snapshots(state: str | None = None, station: str | None = None, limit: int = 50):
    """Get recent telemetry snapshots."""
    records = operational_store.list_telemetry_snapshots(limit=limit, state_name=state, station_name=station)
    return {
        "status": "success",
        "storage": operational_store.status(),
        "total_records": len(records),
        "records": [
            {
                "id": record["id"],
                "timestamp": record["created_at"].isoformat() if record.get("created_at") else None,
                "state": record.get("state_name"),
                "station": record.get("station_name"),
                "request_limit": record.get("request_limit"),
                "snapshot_status": record.get("snapshot_status"),
                "data_source": record.get("data_source"),
                "source_policy_mode": record.get("source_policy_mode"),
                "node_count": record.get("node_count"),
            }
            for record in records
        ],
    }


# ============= AUDIT LOGS =============
@router.get("/audit-logs")
async def get_audit_logs(limit: int = 50):
    """Get recent audit logs."""
    records = operational_store.list_audit_logs(limit=limit)
    return {
        "status": "success",
        "storage": operational_store.status(),
        "total_records": len(records),
        "records": [
            {
                "id": record["id"],
                "timestamp": record["created_at"].isoformat() if record.get("created_at") else None,
                "event_type": record.get("event_type"),
                "route": record.get("route"),
                "event_status": record.get("event_status"),
                "state": record.get("state_name"),
                "station": record.get("station_name"),
                "severity": record.get("severity"),
            }
            for record in records
        ],
    }


# ============= HISTORICAL LOGS =============
@router.get("/historical-logs")
async def get_historical_logs(city: str = "Kolhapur", limit: int = 50):
    """Fetch historical flood logs for a preferred city."""
    try:
        dataset_catalog = [
            {
                "dataset_city": "Kolhapur",
                "file": "kolhapur_flood_logs.csv",
                "aliases": [
                    "kolhapur", "kolhapur district", "kolhapur sector", "shirol",
                    "shirol sector", "irwin bridge", "irwin bridge sector",
                    "irwin bridge kolhapur", "irwin bridge area", "kagal",
                    "kagal high ground", "rajaram barrage", "panchganga",
                ],
            },
        ]

        requested_city = city or "Kolhapur"
        requested_key = _normalize_log_key(requested_city)

        matched_dataset = next(
            (
                dataset
                for dataset in dataset_catalog
                if requested_key
                and any(
                    requested_key == _normalize_log_key(alias)
                    or requested_key in _normalize_log_key(alias)
                    or _normalize_log_key(alias) in requested_key
                    for alias in dataset["aliases"]
                )
            ),
            None,
        )

        logs = []
        if matched_dataset:
            csv_path = matched_dataset["file"]
            candidates = [
                csv_path,
                os.path.join(BASE_DIR, csv_path),
                os.path.join(REPO_DIR, "frontend", "data", csv_path),
                os.path.join(REPO_DIR, "data", csv_path),
            ]
            resolved_csv = next((p for p in candidates if os.path.exists(p)), None)

            if resolved_csv:
                all_rows = []
                with open(resolved_csv, "r", encoding="utf-8") as f:
                    reader = csv.DictReader(f)
                    for row in reader:
                        mapped_row = {
                            "timestamp": row.get("timestamp"),
                            "location": row.get("location"),
                            "peak_level": _safe_float(row.get("peak_level_m")),
                            "rainfall_7day": _safe_float(row.get("rainfall_7day_mm")),
                            "severity": row.get("severity"),
                            "confidence": _safe_float(row.get("confidence_percent")),
                            "alert": row.get("alert_message"),
                            "source": row.get("source"),
                            "dataset_city": matched_dataset["dataset_city"],
                        }
                        all_rows.append(mapped_row)

                def _row_matches(row: Dict[str, Any]) -> bool:
                    haystacks = [
                        row.get("location"),
                        row.get("alert"),
                        row.get("source"),
                        row.get("dataset_city"),
                    ]
                    return any(
                        requested_key in _normalize_log_key(item or "")
                        or _normalize_log_key(item or "") in requested_key
                        for item in haystacks
                    )

                prioritized_rows = [row for row in all_rows if requested_key and _row_matches(row)]
                if prioritized_rows:
                    remaining_rows = [row for row in all_rows if row not in prioritized_rows]
                    logs = prioritized_rows + remaining_rows
                else:
                    logs = all_rows

                logs.sort(key=lambda item: item.get("timestamp") or "", reverse=True)
                logs = logs[:limit]

        return {
            "status": "success",
            "city": requested_city,
            "data_mode": "REAL_DATASET" if logs else "NO_REAL_DATASET",
            "dataset_city": matched_dataset["dataset_city"] if matched_dataset else None,
            "matching_scope": "station_priority" if logs and matched_dataset else None,
            "total_records": len(logs),
            "records": logs,
            "message": None if logs else f"No packaged historical flood dataset is currently mapped to {requested_city}.",
        }
    except Exception as e:
        return {"status": "error", "message": str(e), "records": []}


# ============= SENSORS (TELEMETRY DATA) =============
@router.get("/sensors")
async def get_sensors(station: str = "Kolhapur", state: str = "Bihar"):
    """Get tactical telemetry data for sensors."""
    telemetry = _cwc_scraper._build_tactical_telemetry(
        state_name=state, station_name=station, limit=6
    )
    persist_telemetry_record(
        state, station, 6,
        {
            "status": "POLICY_LOCKED",
            "data": telemetry,
            "data_source": "TACTICAL_REGISTRY",
            "source_policy": get_source_policy_payload(),
        },
        "/sensors",
    )
    return telemetry


# ============= LIVE TELEMETRY =============
@router.get("/api/live-telemetry")
async def get_live_telemetry(
    state: str = "Bihar",
    station: str = "Kolhapur",
    limit: int = 6,
):
    """Get formatted CWC telemetry data."""
    source_policy = get_source_policy_payload()

    if source_policy.get("allow_live_cwc_in_app"):
        telemetry = _cwc_scraper.get_live_telemetry(
            state_name=state, station_name=station, limit=limit
        )
        if not isinstance(telemetry, dict):
            telemetry = {}
        telemetry["source_policy"] = source_policy
    else:
        telemetry = {
            "status": "POLICY_LOCKED",
            "message": source_policy["description"],
            "data_source": "TACTICAL_REGISTRY",
            "source_policy": source_policy,
            "timestamp": current_timestamp_iso(),
            "data": _cwc_scraper._build_tactical_telemetry(
                state_name=state, station_name=station, limit=limit
            ),
        }

    snapshot_id = persist_telemetry_record(state, station, limit, telemetry, "/api/live-telemetry")
    telemetry["snapshot_id"] = snapshot_id
    return telemetry


# ============= CWC LIVE DATA =============
@router.get("/cwc-live-data")
async def get_cwc_live_data(station: str = "Kolhapur"):
    """Fetch live CWC river level data."""
    source_policy = get_source_policy_payload()

    if not source_policy.get("allow_live_cwc_in_app"):
        return {
            "status": "policy_locked",
            "station": station,
            "message": source_policy["description"],
            "source_policy": source_policy,
            "timestamp": current_timestamp_iso(),
        }

    try:
        live_data = _cwc_scraper.get_live_river_level(station)
        if live_data.get("status") in ["success", "success_fallback"]:
            return {
                "status": "success",
                "station": station,
                "current_level_m": live_data.get("current_level_m"),
                "source": live_data.get("source"),
                "source_policy": source_policy,
                "timestamp": current_timestamp_iso(),
                "api": "CWC Official",
            }
        return {
            "status": "error",
            "station": station,
            "message": "Unable to fetch live CWC data",
            "source_policy": source_policy,
            "timestamp": current_timestamp_iso(),
        }
    except Exception as e:
        return {
            "status": "error",
            "station": station,
            "message": str(e),
            "source_policy": source_policy,
            "timestamp": current_timestamp_iso(),
        }
