from fastapi import FastAPI, HTTPException, Request, WebSocket, status
from fastapi.staticfiles import StaticFiles
import asyncio
import copy
import threading
import time
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, Response
from pydantic import BaseModel
import numpy as np
import joblib
from typing import Dict, Any, List
import uvicorn
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import warnings
import os
import re
import hashlib
import json
from dotenv import load_dotenv
from cachetools import TTLCache
import logging

logger = logging.getLogger("opsflood")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.abspath(os.path.join(BASE_DIR, os.pardir))
FRONTEND_DIST_DIR = os.path.join(REPO_DIR, "frontend", "dist")
FRONTEND_INDEX_PATH = os.path.join(FRONTEND_DIST_DIR, "index.html")
DEFAULT_MODEL_ARTIFACTS_DIR = os.path.join(REPO_DIR, "artifacts", "dvc", "models")
MODEL_ARTIFACT_BACKENDS = {"DVC", "FILESYSTEM"}
DEFAULT_MODEL_ARTIFACT_FILES = ("flood_model.pkl", "flood_scaler.pkl")

def refresh_backend_env(override: bool = False):
    load_dotenv(os.path.join(REPO_DIR, ".env"), override=override)
    load_dotenv(os.path.join(REPO_DIR, ".env.local"), override=override)
    load_dotenv(os.path.join(BASE_DIR, ".env"), override=override)
    load_dotenv(os.path.join(BASE_DIR, ".env.local"), override=override)

refresh_backend_env(override=False)

import requests
from bs4 import BeautifulSoup
import datetime

import importlib.util as _importlib_util


def _is_package_context() -> bool:
    return _importlib_util.find_spec("backend") is not None


if _is_package_context():
    from backend.data_pipeline import IngestionTarget, OperationalDataPipeline, ScheduledIngestionService
    from backend.state_severity_matrix import (
        STATE_SEVERITY_MATRIX,
        get_state_severity_entry,
        severity_from_entry,
        build_effective_state_entry,
        select_best_station_node,
    )
    from backend.postgres_store import PostgresOperationalStore
    from backend.model_metrics import evaluate_and_log_metrics
    from backend.cwc_scraper import CWCRiverScraper
    from backend.routers.core import router as core_router
    from backend.routers.predict import router as predict_router
    from backend.routers.weather import router as weather_router
    from backend.routers.telemetry import router as telemetry_router
    from backend.routers.ingestion import router as ingestion_router
    from backend.routers.live_levels import router as live_levels_router, get_live_levels
    from backend.routers.wrd_bihar import router as wrd_bihar_router
    from backend.routers.wrd_bihar import start_scheduler as wrd_start_scheduler
    from backend.routers.wrd_bihar import stop_scheduler as wrd_stop_scheduler
    from backend.routers.wrd_bihar import _fetch_befiqr_live as _wrd_fetch_live
    from backend.routers.wrd_bihar import _tactical_fallback as _wrd_fallback
    from backend.routers.wrd_bihar import _CACHE as _wrd_cache
    from backend.routers.wrd_bihar import _CACHE_KEY as _wrd_cache_key
    from backend.routers.cwc_ffs import router as cwc_ffs_router
    from backend.routers.fcm import router as fcm_router
    from backend.routers.data_gov_cwc import router as data_gov_cwc_router
    from backend.routers.model_artifacts import router as model_artifacts_router
    from backend.routers.metrics import router as metrics_router
    from backend.routers.glofas import router as glofas_router
    from backend.routers.rainfall import router as rainfall_router
    from backend.routers.cwc_stations import router as cwc_stations_router
    from backend.routers.news import router as news_router
    from backend.ml.bootstrap_model import ensure_model_exists
    from backend.routers.fastapi_contracts import router as flutter_contracts_router
    from backend.ws_server import ws_gauges_endpoint

else:
    from data_pipeline import IngestionTarget, OperationalDataPipeline, ScheduledIngestionService
    from state_severity_matrix import (
        STATE_SEVERITY_MATRIX,
        get_state_severity_entry,
        severity_from_entry,
        build_effective_state_entry,
        select_best_station_node,
    )
    from postgres_store import PostgresOperationalStore
    from model_metrics import evaluate_and_log_metrics
    from cwc_scraper import CWCRiverScraper
    from routers.core import router as core_router
    from routers.predict import router as predict_router
    from routers.weather import router as weather_router
    from routers.telemetry import router as telemetry_router
    from routers.ingestion import router as ingestion_router
    from routers.live_levels import router as live_levels_router, get_live_levels
    from routers.wrd_bihar import router as wrd_bihar_router
    from routers.wrd_bihar import start_scheduler as wrd_start_scheduler
    from routers.wrd_bihar import stop_scheduler as wrd_stop_scheduler
    from routers.wrd_bihar import _fetch_befiqr_live as _wrd_fetch_live
    from routers.wrd_bihar import _tactical_fallback as _wrd_fallback
    from routers.wrd_bihar import _CACHE as _wrd_cache
    from routers.wrd_bihar import _CACHE_KEY as _wrd_cache_key
    from routers.cwc_ffs import router as cwc_ffs_router
    from routers.fcm import router as fcm_router
    from routers.data_gov_cwc import router as data_gov_cwc_router
    from routers.model_artifacts import router as model_artifacts_router
    from routers.metrics import router as metrics_router
    from routers.glofas import router as glofas_router
    from routers.rainfall import router as rainfall_router
    from routers.cwc_stations import router as cwc_stations_router
    from routers.news import router as news_router
    from ml.bootstrap_model import ensure_model_exists
    from ws_server import ws_gauges_endpoint


warnings.filterwarnings('ignore')
operational_store = PostgresOperationalStore()
operational_store.initialize()

SOURCE_POLICY_MODES = {"OPEN_DATA", "OFFICIAL_VIEW_ONLY", "FALLBACK"}


def env_flag(key: str, default: bool = False) -> bool:
    val = os.getenv(key, "").strip().lower()
    if val in ("1", "true", "yes"):
        return True
    if val in ("0", "false", "no"):
        return False
    return default


def get_source_policy_mode() -> str:
    refresh_backend_env(override=True)
    configured = (os.getenv("FLOOD_SOURCE_POLICY") or "OFFICIAL_VIEW_ONLY").strip().upper()
    return configured if configured in SOURCE_POLICY_MODES else "OFFICIAL_VIEW_ONLY"


def live_cwc_enabled() -> bool:
    return env_flag("ENABLE_LIVE_CWC_IN_APP", default=True)


def get_source_policy_payload() -> Dict[str, Any]:
    mode = get_source_policy_mode()
    allow_live_cwc = live_cwc_enabled() and mode != "FALLBACK"
    base_sources = [
        {
            "label": "Open Data",
            "title": "data.gov.in Reservoir Levels",
            "url": "https://www.data.gov.in/resource/daily-data-reservoir-level-central-water-commission-cwc",
            "usage": "Safest public reuse path",
        },
        {
            "label": "Official Monitor",
            "title": "CWC Flood Forecast Portal",
            "url": "https://ffs.india-water.gov.in/",
            "usage": "Authoritative public viewing",
        },
        {
            "label": "Advisory",
            "title": "CWC 7-Day Forecast",
            "url": "https://aff.india-water.gov.in/home.php",
            "usage": "Forward-looking official advisories",
        },
    ]

    if mode == "OPEN_DATA":
        return {
            "mode": mode,
            "label": "Open Data",
            "description": "Use open/publicly reusable datasets as the legal default. Live CWC telemetry is enabled for automatic operational monitoring."
            if allow_live_cwc
            else "Use open/publicly reusable datasets as the legal default. Live in-app CWC scraping is disabled.",
            "allow_live_cwc_in_app": allow_live_cwc,
            "telemetry_mode": "LIVE_CWC_CONTEXT" if allow_live_cwc else "OPEN_DATA_CONTEXT",
            "prediction_data_source": "Live CWC + Open Data Context" if allow_live_cwc else "Open Data Context + Manual Input",
            "public_sources": base_sources,
        }

    if mode == "FALLBACK":
        return {
            "mode": mode,
            "label": "Fallback",
            "description": "Operate on tactical registry context and manual thresholds only. No official live ingestion is attempted in-app.",
            "allow_live_cwc_in_app": False,
            "telemetry_mode": "TACTICAL_FALLBACK",
            "prediction_data_source": "Fallback Manual Context",
            "public_sources": base_sources,
        }

    return {
        "mode": "OFFICIAL_VIEW_ONLY",
        "label": "Official View Only",
        "description": "Official CWC telemetry is enabled for fully automatic in-app danger-level detection."
        if allow_live_cwc
        else "Use official CWC portals for public monitoring, but keep in-app telemetry on manual or tactical context unless explicit reuse rights are obtained.",
        "allow_live_cwc_in_app": allow_live_cwc,
        "telemetry_mode": "OFFICIAL_LIVE_IN_APP" if allow_live_cwc else "OFFICIAL_VIEW_ONLY",
        "prediction_data_source": "Live CWC Detection + Manual Input" if allow_live_cwc else "Official View Only + Manual Input",
        "public_sources": base_sources,
    }


def current_timestamp_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def model_to_dict(model: Any) -> Dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump()
    if hasattr(model, "dict"):
        return model.dict()
    return dict(model)


def calculate_rainfall_total(input_payload: Dict[str, Any]) -> float:
    return round(
        sum(float(input_payload.get(key) or 0.0) for key in ("T1d", "T2d", "T3d", "T4d", "T5d", "T6d", "T7d")),
        3,
    )


def write_audit_log(
    *,
    event_type: str,
    route: str,
    event_status: str,
    state_name: str | None = None,
    station_name: str | None = None,
    severity: str | None = None,
    details: Dict[str, Any] | None = None,
) -> int | None:
    try:
        return operational_store.save_audit_log(
            {
                "event_type": event_type,
                "route": route,
                "event_status": event_status,
                "state_name": state_name,
                "station_name": station_name,
                "severity": severity,
                "details": details or {},
            }
        )
    except Exception as exc:
        print(f"\u26a0\ufe0f Audit log persistence failed: {exc}")
        return None


def persist_prediction_record(input_data: Any, result: Dict[str, Any]) -> int | None:
    input_payload = model_to_dict(input_data)
    station_name = str(input_payload.get("station") or "").strip() or None
    state_name = str(input_payload.get("state") or "Maharashtra").strip()
    rainfall_total = calculate_rainfall_total(input_payload)

    try:
        prediction_id = operational_store.save_prediction(
            {
                "state_name": state_name,
                "city_name": station_name,
                "station_name": station_name,
                "peak_level_m": float(input_payload.get("Peak_Flood_Level_m") or 0.0),
                "rainfall_total_mm": rainfall_total,
                "severity": str(result.get("severity") or "UNKNOWN"),
                "confidence_percent": float(result.get("confidence_percent") or 0.0),
                "risk_score": int(result.get("risk_score") or 0),
                "data_source": str(result.get("data_source") or ""),
                "algorithm": str(result.get("algorithm") or ""),
                "model_version": str(result.get("algorithm") or ""),
                "monitoring_level": str((result.get("monitoring") or {}).get("level") or ""),
                "monitoring_action": str((result.get("monitoring") or {}).get("action") or ""),
                "source_policy_mode": str((result.get("source_policy") or {}).get("mode") or ""),
                "source_policy_label": str((result.get("source_policy") or {}).get("label") or ""),
                "input_payload": input_payload,
                "prediction_payload": result,
            }
        )
    except Exception as exc:
        print(f"\u26a0\ufe0f Prediction persistence failed: {exc}")
        prediction_id = None

    write_audit_log(
        event_type="prediction.inference",
        route="/predict",
        event_status="success" if prediction_id else "skipped",
        state_name=state_name,
        station_name=station_name,
        severity=str(result.get("severity") or "UNKNOWN"),
        details={
            "prediction_id": prediction_id,
            "data_source": result.get("data_source"),
            "confidence_percent": result.get("confidence_percent"),
            "risk_score": result.get("risk_score"),
            "storage_ready": operational_store.status().get("ready"),
        },
    )
    return prediction_id


def persist_telemetry_record(state_name: str, station_name: str, limit: int, telemetry: Dict[str, Any], route: str) -> int | None:
    node_count = len(telemetry.get("data", [])) if isinstance(telemetry.get("data"), list) else 0

    try:
        snapshot_id = operational_store.save_telemetry_snapshot(
            {
                "state_name": state_name,
                "station_name": station_name,
                "request_limit": int(limit),
                "snapshot_status": str(telemetry.get("status") or ""),
                "data_source": str(telemetry.get("data_source") or ""),
                "source_policy_mode": str(((telemetry.get("source_policy") or {}).get("mode")) or ""),
                "node_count": node_count,
                "payload": telemetry,
            }
        )
    except Exception as exc:
        print(f"\u26a0\ufe0f Telemetry snapshot persistence failed: {exc}")
        snapshot_id = None

    write_audit_log(
        event_type="telemetry.snapshot",
        route=route,
        event_status="success" if snapshot_id else "skipped",
        state_name=state_name,
        station_name=station_name,
        details={
            "snapshot_id": snapshot_id,
            "node_count": node_count,
            "telemetry_status": telemetry.get("status"),
            "data_source": telemetry.get("data_source"),
            "storage_ready": operational_store.status().get("ready"),
        },
    )
    return snapshot_id


def build_policy_bound_telemetry(state_name: str = "Maharashtra", station_name: str = "Kolhapur", limit: int = 6) -> Dict[str, Any]:
    policy = get_source_policy_payload()
    if policy.get("allow_live_cwc_in_app"):
        pass
    return policy


# ---------------------------------------------------------------------------
# GloFAS warm cache  (non-Bihar states only)
# ---------------------------------------------------------------------------

GLOFAS_STATION_CACHE: List[Dict[str, Any]] = []
_glofas_cache_lock = threading.Lock()

_GLOFAS_STATIONS = [
    {"station_name": "Kolhapur",     "state_name": "Maharashtra",      "river_name": "Panchganga",    "lat": 16.705, "lon": 74.243,  "warning_discharge": 1200.0,  "danger_discharge": 2000.0},
    {"station_name": "Kochi",        "state_name": "Kerala",           "river_name": "Periyar",       "lat": 9.931,  "lon": 76.267,  "warning_discharge": 800.0,   "danger_discharge": 1400.0},
    {"station_name": "Guwahati",     "state_name": "Assam",            "river_name": "Brahmaputra",   "lat": 26.144, "lon": 91.736,  "warning_discharge": 40000.0, "danger_discharge": 72000.0},
    {"station_name": "Haridwar",     "state_name": "Uttarakhand",      "river_name": "Ganga",         "lat": 29.945, "lon": 78.164,  "warning_discharge": 5000.0,  "danger_discharge": 9000.0},
    {"station_name": "Surat",        "state_name": "Gujarat",          "river_name": "Tapi",          "lat": 21.170, "lon": 72.831,  "warning_discharge": 3000.0,  "danger_discharge": 6000.0},
    {"station_name": "Cuttack",      "state_name": "Odisha",           "river_name": "Mahanadi",      "lat": 20.462, "lon": 85.883,  "warning_discharge": 14000.0, "danger_discharge": 25000.0},
    {"station_name": "Kolkata",      "state_name": "West Bengal",      "river_name": "Hooghly",       "lat": 22.573, "lon": 88.364,  "warning_discharge": 6000.0,  "danger_discharge": 11000.0},
    {"station_name": "Varanasi",     "state_name": "Uttar Pradesh",    "river_name": "Ganga",         "lat": 25.317, "lon": 83.005,  "warning_discharge": 20000.0, "danger_discharge": 36000.0},
    {"station_name": "Vijayawada",   "state_name": "Andhra Pradesh",   "river_name": "Krishna",       "lat": 16.506, "lon": 80.648,  "warning_discharge": 5000.0,  "danger_discharge": 10000.0},
    {"station_name": "Jabalpur",     "state_name": "Madhya Pradesh",   "river_name": "Narmada",       "lat": 23.181, "lon": 79.987,  "warning_discharge": 4000.0,  "danger_discharge": 8000.0},
    {"station_name": "Raipur",       "state_name": "Chhattisgarh",     "river_name": "Mahanadi",      "lat": 21.251, "lon": 81.630,  "warning_discharge": 2500.0,  "danger_discharge": 5000.0},
    {"station_name": "Ludhiana",     "state_name": "Punjab",           "river_name": "Sutlej",        "lat": 30.901, "lon": 75.857,  "warning_discharge": 3000.0,  "danger_discharge": 6000.0},
    {"station_name": "Pasighat",     "state_name": "Arunachal Pradesh","river_name": "Brahmaputra",   "lat": 28.067, "lon": 95.333,  "warning_discharge": 8000.0,  "danger_discharge": 15000.0},
    {"station_name": "Imphal",       "state_name": "Manipur",          "river_name": "Imphal River",  "lat": 24.817, "lon": 93.936,  "warning_discharge": 300.0,   "danger_discharge": 600.0},
    {"station_name": "Shillong",     "state_name": "Meghalaya",        "river_name": "Umiam",         "lat": 25.567, "lon": 91.883,  "warning_discharge": 250.0,   "danger_discharge": 500.0},
    {"station_name": "Agartala",     "state_name": "Tripura",          "river_name": "Haora",         "lat": 23.831, "lon": 91.286,  "warning_discharge": 200.0,   "danger_discharge": 400.0},
    {"station_name": "Gangtok",      "state_name": "Sikkim",           "river_name": "Teesta",        "lat": 27.329, "lon": 88.612,  "warning_discharge": 500.0,   "danger_discharge": 1000.0},
    {"station_name": "New Delhi",    "state_name": "Delhi",            "river_name": "Yamuna",        "lat": 28.644, "lon": 77.216,  "warning_discharge": 5000.0,  "danger_discharge": 9000.0},
    {"station_name": "Srinagar",     "state_name": "Jammu and Kashmir","river_name": "Jhelum",        "lat": 34.083, "lon": 74.797,  "warning_discharge": 1500.0,  "danger_discharge": 3000.0},
    {"station_name": "Mysuru",       "state_name": "Karnataka",        "river_name": "Kaveri",        "lat": 12.296, "lon": 76.639,  "warning_discharge": 2000.0,  "danger_discharge": 4000.0},
    {"station_name": "Chennai",      "state_name": "Tamil Nadu",       "river_name": "Adyar",         "lat": 13.083, "lon": 80.271,  "warning_discharge": 800.0,   "danger_discharge": 1500.0},
    {"station_name": "Dhanbad",      "state_name": "Jharkhand",        "river_name": "Damodar",       "lat": 23.800, "lon": 86.433,  "warning_discharge": 1500.0,  "danger_discharge": 3000.0},
    {"station_name": "Ambala",       "state_name": "Haryana",          "river_name": "Ghaggar",       "lat": 30.378, "lon": 76.776,  "warning_discharge": 800.0,   "danger_discharge": 1600.0},
    {"station_name": "Mandi",        "state_name": "Himachal Pradesh", "river_name": "Beas",          "lat": 31.709, "lon": 76.932,  "warning_discharge": 1000.0,  "danger_discharge": 2000.0},
    {"station_name": "Kota",         "state_name": "Rajasthan",        "river_name": "Chambal",       "lat": 25.183, "lon": 75.833,  "warning_discharge": 2000.0,  "danger_discharge": 4000.0},
    {"station_name": "Hyderabad",    "state_name": "Telangana",        "river_name": "Musi",          "lat": 17.385, "lon": 78.487,  "warning_discharge": 1000.0,  "danger_discharge": 2000.0},
    {"station_name": "Panaji",       "state_name": "Goa",              "river_name": "Mandovi",       "lat": 15.499, "lon": 73.824,  "warning_discharge": 400.0,   "danger_discharge": 800.0},
    {"station_name": "Dimapur",      "state_name": "Nagaland",         "river_name": "Dhansiri",      "lat": 25.900, "lon": 93.726,  "warning_discharge": 300.0,   "danger_discharge": 600.0},
    {"station_name": "Aizawl",       "state_name": "Mizoram",          "river_name": "Tlawng",        "lat": 23.727, "lon": 92.717,  "warning_discharge": 200.0,   "danger_discharge": 400.0},
]

GLOFAS_API_URL = "https://flood-api.open-meteo.com/v1/flood"
GLOFAS_REFRESH_INTERVAL_SECONDS = 900
GLOFAS_REQUEST_TIMEOUT_SECONDS = 15
_glofas_thread: threading.Thread | None = None
_glofas_stop_event = threading.Event()


def _fetch_glofas_station(station: Dict[str, Any]) -> Dict[str, Any] | None:
    try:
        resp = requests.get(
            GLOFAS_API_URL,
            params={
                "latitude": station["lat"],
                "longitude": station["lon"],
                "daily": "river_discharge",
                "forecast_days": 1,
            },
            timeout=GLOFAS_REQUEST_TIMEOUT_SECONDS,
        )
        if not resp.ok:
            return None
        data = resp.json()
        daily = data.get("daily", {})
        discharge_list = daily.get("river_discharge") or []
        discharge = float(discharge_list[0]) if discharge_list else 0.0

        warning_q = station["warning_discharge"]
        danger_q  = station["danger_discharge"]

        if danger_q > 0 and discharge >= danger_q:
            risk = "CRITICAL"
        elif warning_q > 0 and discharge >= warning_q:
            risk = "HIGH"
        elif warning_q > 0 and discharge >= warning_q * 0.7:
            risk = "MODERATE"
        else:
            risk = "LOW"

        return {
            **station,
            "river_discharge":   discharge,
            "warning_discharge": warning_q,
            "danger_discharge":  danger_q,
            "risk_level":        risk,
            "timestamp":         current_timestamp_iso(),
        }
    except Exception as exc:
        logger.warning(f"\u26a0\ufe0f  GloFAS fetch failed for {station['station_name']}: {exc}")
        return None


def _refresh_glofas_cache() -> int:
    updated: List[Dict[str, Any]] = []
    for station in _GLOFAS_STATIONS:
        result = _fetch_glofas_station(station)
        if result is not None:
            updated.append(result)
    if updated:
        with _glofas_cache_lock:
            GLOFAS_STATION_CACHE.clear()
            GLOFAS_STATION_CACHE.extend(updated)
        logger.info(f"[GloFAS] Cache refreshed — {len(updated)}/{len(_GLOFAS_STATIONS)} stations")
    else:
        logger.warning("[GloFAS] All station fetches failed — cache unchanged")
    return len(updated)


def _glofas_warm_cache_loop():
    logger.info("[GloFAS] warm_cache thread started")
    while not _glofas_stop_event.is_set():
        try:
            _refresh_glofas_cache()
        except Exception as exc:
            logger.warning(f"[GloFAS] Refresh cycle error (non-fatal): {exc}")
        _glofas_stop_event.wait(timeout=GLOFAS_REFRESH_INTERVAL_SECONDS)
    logger.info("[GloFAS] warm_cache thread stopped")


def start_glofas_thread():
    global _glofas_thread
    if _glofas_thread and _glofas_thread.is_alive():
        return
    _glofas_stop_event.clear()
    _glofas_thread = threading.Thread(
        target=_glofas_warm_cache_loop,
        name="warm_cache",
        daemon=True,
    )
    _glofas_thread.start()


def stop_glofas_thread():
    _glofas_stop_event.set()


# ---------------------------------------------------------------------------
# WRD Bihar eager warm
# ---------------------------------------------------------------------------

def _eager_warm_wrd_bihar() -> None:
    logger.info("[WRD Bihar] Eager warm starting...")
    try:
        result = _wrd_fetch_live()
        _wrd_cache[_wrd_cache_key] = result
        logger.info(
            f"[WRD Bihar] Eager warm complete — "
            f"{result['station_count']} stations from {result['data_source']}"
        )
    except Exception as exc:
        logger.warning(f"[WRD Bihar] Eager warm failed ({exc}) — loading fallback registry")
        try:
            fallback = _wrd_fallback(str(exc))
            _wrd_cache[_wrd_cache_key] = fallback
            logger.info(f"[WRD Bihar] Fallback loaded — {fallback['station_count']} stations")
        except Exception as fb_exc:
            logger.warning(f"[WRD Bihar] Fallback also failed: {fb_exc}")


def start_wrd_bihar_eager_warm() -> None:
    t = threading.Thread(target=_eager_warm_wrd_bihar, name="wrd_bihar_eager_warm", daemon=True)
    t.start()


# ---------------------------------------------------------------------------
# P2: Bootstrap model
# ---------------------------------------------------------------------------

def _run_model_bootstrap() -> None:
    try:
        ensure_model_exists()
    except Exception as exc:
        logger.warning(f"[Bootstrap] Model bootstrap failed (non-fatal): {exc}")


def start_model_bootstrap() -> None:
    t = threading.Thread(target=_run_model_bootstrap, name="model_bootstrap", daemon=True)
    t.start()


# ── FastAPI application ─────────────────────────────────────────────────────
app = FastAPI(
    title="OpsFlood API",
    description="Flood monitoring, prediction and telemetry backend for the Android Flood App.",
    version="1.3.0",
)


import os as _os

_origins = _os.environ.get("ALLOWED_ORIGINS", "").split(",")
ALLOWED_ORIGINS = [o.strip() for o in _origins if o.strip()] or [
    "https://android-flood-app-production.up.railway.app",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(core_router)
app.include_router(predict_router)
app.include_router(weather_router)
app.include_router(telemetry_router)
app.include_router(ingestion_router)
app.include_router(live_levels_router)
app.include_router(wrd_bihar_router)
app.include_router(cwc_ffs_router)
app.include_router(fcm_router)
app.include_router(data_gov_cwc_router)
app.include_router(model_artifacts_router)
app.include_router(metrics_router)
app.include_router(glofas_router)
app.include_router(rainfall_router)
app.include_router(cwc_stations_router)
app.include_router(news_router)
app.include_router(flutter_contracts_router)


# ── WebSocket route — REGISTERED HERE ──────────────────────────────────────
# This was missing before; ws_server.py existed but was never mounted.
@app.websocket("/ws/gauges")
async def ws_gauges(websocket: WebSocket):
    """
    Live gauge data stream.
    Clients connect with wss://…/ws/gauges
    Server pushes updates every 45 s + on-demand via push_update().
    """
    await ws_gauges_endpoint(websocket, get_live_levels)


# ── HTTP health for Railway's healthcheck probe ─────────────────────────────
@app.get("/ws/gauges/health", include_in_schema=False)
async def ws_health():
    """Lets Railway's HTTP healthcheck confirm the WS path is reachable."""
    return {"status": "ws_ready", "path": "/ws/gauges"}


@app.on_event("startup")
async def startup_event():
    logger.info("OpsFlood API starting up — version 1.3.0")
    try:
        start_model_bootstrap()
        logger.info("[Bootstrap] Model bootstrap thread launched")
    except Exception as exc:
        logger.warning(f"[Bootstrap] Thread launch failed (non-fatal): {exc}")
    try:
        start_wrd_bihar_eager_warm()
        logger.info("WRD Bihar eager warm thread launched")
    except Exception as exc:
        logger.warning(f"WRD Bihar eager warm failed (non-fatal): {exc}")
    try:
        wrd_start_scheduler()
        logger.info("WRD Bihar APScheduler started")
    except Exception as exc:
        logger.warning(f"WRD Bihar scheduler start failed (non-fatal): {exc}")
    try:
        start_glofas_thread()
        logger.info("GloFAS warm_cache thread started")
    except Exception as exc:
        logger.warning(f"GloFAS thread start failed (non-fatal): {exc}")


@app.on_event("shutdown")
async def shutdown_event():
    logger.info("OpsFlood API shutting down")
    try:
        wrd_stop_scheduler()
    except Exception as exc:
        logger.warning(f"WRD Bihar scheduler stop failed (non-fatal): {exc}")
    try:
        stop_glofas_thread()
    except Exception as exc:
        logger.warning(f"GloFAS thread stop failed (non-fatal): {exc}")


@app.get("/health")
async def health():
    glofas_count = len(GLOFAS_STATION_CACHE)
    return {
        "status": "ok",
        "version": "1.3.0",
        "timestamp": current_timestamp_iso(),
        "glofas_stations_cached": glofas_count,
    }


@app.get("/api/source-policy")
async def source_policy():
    return get_source_policy_payload()


if os.path.isdir(FRONTEND_DIST_DIR):
    app.mount("/assets", StaticFiles(directory=os.path.join(FRONTEND_DIST_DIR, "assets")), name="assets")

    @app.get("/{full_path:path}", include_in_schema=False)
    async def serve_frontend(full_path: str):
        file_path = os.path.join(FRONTEND_DIST_DIR, full_path)
        if os.path.isfile(file_path):
            return FileResponse(file_path)
        return FileResponse(FRONTEND_INDEX_PATH)
