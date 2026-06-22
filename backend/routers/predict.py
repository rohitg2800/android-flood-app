"""
Prediction router: ML model predictions, artifacts, and state severity matrix endpoints.

Fix (v2-wired):
  When predictor=None (FastAPI DI never wired), /predict/v2 and /predict/legacy
  now instantiate FloodPredictor(station) directly from ml/flood_predictor.py and
  call .predict() so the BiLSTM / physics model is always used.
  The old hardcoded MODERATE fallback is only kept as a last-resort except guard.

New (river-severity):
  GET /api/river-severity — bulk endpoint that reads the live-levels cache
  (WRD Bihar + GloFAS), runs FloodPredictor per city, and returns a
  severity-ranked list.  Flutter map/list calls ONE URL for all cities.
"""

import importlib.util as _importlib_util
import asyncio
import concurrent.futures
from typing import Any, Dict, List, Optional
from fastapi import APIRouter
from pydantic import BaseModel

from .dependencies import (
    get_source_policy_payload,
    model_to_dict,
    write_audit_log,
    calculate_rainfall_total,
    operational_store,
    STATE_SEVERITY_MATRIX,
    get_state_severity_entry,
    build_effective_state_entry,
    select_best_station_node,
    get_pipeline_features,
    pipeline_autofill_predict_input,
)
from .model_artifacts import discover_model_artifacts, discover_model_bundles, discover_legacy_artifacts_outside_store

router = APIRouter(tags=["prediction"])


class FloodPredictionInput(BaseModel):
    Peak_Flood_Level_m: float = 8.5
    Event_Duration_days: float = 1
    Time_to_Peak_days: float = 1
    Recession_Time_day: float = 1
    T1d: float = 10.0
    T2d: float = 15.0
    T3d: float = 20.0
    T4d: float = 18.0
    T5d: float = 12.0
    T6d: float = 8.0
    T7d: float = 7.0
    state: str = "Bihar"
    station: str | None = None


# ── FloodPredictor import (lazy) ─────────────────────────────────────────────
def _get_flood_predictor_cls():
    try:
        if _importlib_util.find_spec("backend") is not None:
            from backend.ml.flood_predictor import FloodPredictor
        else:
            from ml.flood_predictor import FloodPredictor  # type: ignore
        return FloodPredictor
    except Exception:
        return None


def _run_flood_predictor(
    input_data: "FloodPredictionInput",
    data_source: str,
    effective_entry: dict | None,
) -> dict:
    FloodPredictor = _get_flood_predictor_cls()
    if FloodPredictor is None:
        raise RuntimeError("FloodPredictor could not be imported")

    station = (input_data.station or "").strip() or "Gandhighat"
    predictor = FloodPredictor(station)

    rainfall_3d = input_data.T1d + input_data.T2d + input_data.T3d
    rainfall_7d = sum([
        input_data.T1d, input_data.T2d, input_data.T3d,
        input_data.T4d, input_data.T5d, input_data.T6d, input_data.T7d,
    ])

    raw = predictor.predict(
        current_level=input_data.Peak_Flood_Level_m,
        rainfall_3d_mm=rainfall_3d,
        rainfall_7d_mm=rainfall_7d,
    )

    danger_level = float(
        (effective_entry or {}).get("danger_level_m")
        or raw.get("danger_level")
        or 50.0
    )
    warning_level = float(
        (effective_entry or {}).get("warning_level_m")
        or raw.get("warning_level")
        or danger_level * 0.85
    )
    current = float(raw.get("current_level") or input_data.Peak_Flood_Level_m)
    ratio = current / danger_level if danger_level > 0 else 0.0

    if ratio >= 1.0:
        severity = "CRITICAL"
        risk_score = 100
    elif ratio >= 0.90:
        severity = "SEVERE"
        risk_score = int(ratio * 100)
    elif ratio >= 0.70:
        severity = "MODERATE"
        risk_score = int(ratio * 100)
    else:
        severity = "LOW"
        risk_score = int(ratio * 100)

    will_breach = raw.get("will_breach_danger", False)
    confidence  = float(raw.get("confidence_pct", 65.0))
    model_ver   = raw.get("model_version", "v1.0-physics")
    algorithm   = "BiLSTM" if "lstm" in model_ver else "Physics-Trend"

    _sev_order = ["LOW", "MODERATE", "SEVERE", "CRITICAL"]
    _sev_idx   = _sev_order.index(severity)
    probs: dict[str, float] = {s: 0.0 for s in _sev_order}
    probs[severity] = round(confidence, 1)
    remaining = round(100.0 - confidence, 1)
    if _sev_idx + 1 < len(_sev_order):
        probs[_sev_order[_sev_idx + 1]] = remaining
    else:
        probs[_sev_order[_sev_idx - 1]] = remaining

    alert_icon = (
        "\U0001f6a8" if severity == "CRITICAL"
        else "\u26a0\ufe0f" if severity in ("SEVERE", "MODERATE")
        else "\u2705"
    )

    return {
        "severity":          severity,
        "confidence_percent": confidence,
        "probabilities":     probs,
        "alert":             alert_icon,
        "algorithm":         algorithm,
        "data_source":       data_source,
        "model_trained":     True,
        "model_version":     model_ver,
        "risk_score":        risk_score,
        "state":             input_data.state,
        "station":           station,
        "danger_level_m":    danger_level,
        "warning_level_m":   warning_level,
        "will_breach_danger": will_breach,
        "next_24h":          raw.get("next_24h", []),
        "peak_level":        raw.get("peak_level"),
    }


# ── Shared helper: severity from a live-levels record ──────────────────────────────
def _severity_from_live_record(record: Dict[str, Any]) -> Dict[str, Any]:
    """
    Given one record from _build_all_levels(), run FloodPredictor and
    return a dict with predicted_severity + supporting fields.
    Used by both /api/river-severity and live_levels._attach_predicted_severity().
    """
    FloodPredictor = _get_flood_predictor_cls()

    city         = str(record.get("city") or record.get("station") or "").strip()
    state        = str(record.get("state") or "").strip()
    river_level  = float(record.get("current_level") or 0.0)
    danger_m     = float(record.get("danger_level")  or 50.0)
    warning_m    = float(record.get("warning_level") or danger_m * 0.85)
    discharge    = float(record.get("river_discharge") or record.get("flow_rate") or 0.0)
    # Rainfall proxies: use telemetry fields when available
    rain_1h      = float(record.get("rainfall_1h_mm") or 0.0)
    # Approximate 3d / 7d from discharge trend when rainfall not stored
    rain_3d      = rain_1h * 24 * 3 if rain_1h > 0 else discharge * 0.008
    rain_7d      = rain_1h * 24 * 7 if rain_1h > 0 else discharge * 0.018

    default_out = {
        "predicted_severity":  None,
        "risk_score":          None,
        "confidence_percent":  None,
        "will_breach_danger":  None,
        "peak_level_72h":      None,
        "algorithm":           None,
        "model_version":       None,
    }

    if not city or river_level == 0.0:
        return default_out

    try:
        if FloodPredictor is None:
            raise RuntimeError("FloodPredictor unavailable")
        predictor = FloodPredictor(city)
        raw = predictor.predict(
            current_level=river_level,
            rainfall_3d_mm=rain_3d,
            rainfall_7d_mm=rain_7d,
        )
        peak       = float(raw.get("peak_level") or river_level)
        will_breach = bool(raw.get("will_breach_danger", False))
        confidence  = float(raw.get("confidence_pct", 65.0))
        model_ver   = str(raw.get("model_version", "v1.0-physics"))
        algo        = "BiLSTM" if "lstm" in model_ver else "Physics-Trend"

        # Use model danger if station is in GAUGE_THRESHOLDS, else record's danger_m
        eff_danger  = float(raw.get("danger_level") or danger_m)
        ratio       = river_level / eff_danger if eff_danger > 0 else 0.0

        if ratio >= 1.0:   sev, score = "CRITICAL", 100
        elif ratio >= 0.90: sev, score = "SEVERE",   int(ratio * 100)
        elif ratio >= 0.70: sev, score = "MODERATE", int(ratio * 100)
        else:               sev, score = "LOW",      int(ratio * 100)

        # Override to CRITICAL when model says breach imminent
        if will_breach and sev not in ("CRITICAL", "SEVERE"):
            sev   = "SEVERE"
            score = max(score, 90)

        return {
            "predicted_severity": sev,
            "risk_score":         score,
            "confidence_percent": confidence,
            "will_breach_danger": will_breach,
            "peak_level_72h":     round(peak, 3),
            "algorithm":          algo,
            "model_version":      model_ver,
        }
    except Exception as exc:
        print(f"[river-severity] predictor failed for {city}: {exc}")
        # Graceful fallback using threshold ratio from live record
        ratio = river_level / danger_m if danger_m > 0 else 0.0
        if ratio >= 1.0:   sev, score = "CRITICAL", 100
        elif ratio >= 0.90: sev, score = "SEVERE",   int(ratio * 100)
        elif ratio >= 0.70: sev, score = "MODERATE", int(ratio * 100)
        else:               sev, score = "LOW",      int(ratio * 100)
        return {
            "predicted_severity": sev,
            "risk_score":         score,
            "confidence_percent": 55.0,
            "will_breach_danger": sev in ("CRITICAL", "SEVERE"),
            "peak_level_72h":     None,
            "algorithm":          "Threshold-Ratio-Fallback",
            "model_version":      "fallback",
        }


# ── Bihar RandomForest Model (trained on real station data) ───────────────────
import os as _os
import joblib as _joblib
import numpy as _np

_BIHAR_RF_MODEL  = None
_BIHAR_RF_SCALER = None
_BIHAR_RF_COLS   = None
_BIHAR_DANGER    = {
    'patna':       {'w': 47.50, 'd': 48.60, 'h': 50.52},
    'gandhighat':  {'w': 47.50, 'd': 48.60, 'h': 50.52},
    'dighaghat':   {'w': 49.30, 'd': 50.45, 'h': 52.52},
    'birpur':      {'w': 73.70, 'd': 76.02, 'h': 77.10},
    'munger':      {'w': 38.20, 'd': 39.33, 'h': 40.99},
    'bhagalpur':   {'w': 32.50, 'd': 33.68, 'h': 34.86},
    'hajipur':     {'w': 49.40, 'd': 50.32, 'h': 50.93},
    'basua':       {'w': 47.00, 'd': 48.00, 'h': 49.50},
    'baltara':     {'w': 32.50, 'd': 33.85, 'h': 36.40},
    'kursela':     {'w': 28.00, 'd': 30.00, 'h': 32.10},
    'jhanjharpur': {'w': 48.00, 'd': 50.00, 'h': 53.11},
    'benibad':     {'w': 47.00, 'd': 48.68, 'h': 50.12},
    'samastipur':  {'w': 44.80, 'd': 46.00, 'h': 49.40},
    'khagaria':    {'w': 34.65, 'd': 35.65, 'h': 47.30},
    'buxar':       {'w': 59.20, 'd': 60.30, 'h': 62.10},
    'darauli':     {'w': 60.50, 'd': 60.82, 'h': 61.82},
    'dumariaghat': {'w': 61.10, 'd': 62.22, 'h': 64.36},
    'dhengraghat': {'w': 35.00, 'd': 35.65, 'h': 38.20},
}

def _load_bihar_rf():
    global _BIHAR_RF_MODEL, _BIHAR_RF_SCALER, _BIHAR_RF_COLS
    if _BIHAR_RF_MODEL is not None:
        return True
    try:
        base = _os.path.join(_os.path.dirname(__file__), '..', '..', 'artifacts', 'dvc', 'models')
        _BIHAR_RF_MODEL  = _joblib.load(_os.path.join(base, 'flood_model.pkl'))
        _BIHAR_RF_SCALER = _joblib.load(_os.path.join(base, 'flood_scaler.pkl'))
        _BIHAR_RF_COLS   = _joblib.load(_os.path.join(base, 'feature_columns.pkl'))
        print('[BiharRF] model loaded successfully')
        return True
    except Exception as e:
        print(f'[BiharRF] load failed: {e}')
        return False

def _bihar_rf_predict(station: str, level_m: float, rain_1h: float = 2.0,
                      rain_3d: float = 10.0, rain_7d: float = 25.0,
                      upstream: float = None, day_sin: float = 0.5,
                      day_cos: float = 0.866, hour_sin: float = 0.0):
    if not _load_bihar_rf():
        return None
    key = station.lower().strip()
    t   = _BIHAR_DANGER.get(key)
    if t is None:
        return None
    upstream = upstream or level_m * 1.01
    feat = {
        'level_pct_danger':    level_m / t['d'],
        'level_pct_warning':   level_m / t['w'],
        'rain_1h':             rain_1h,
        'rain_3d':             rain_3d,
        'rain_7d':             rain_7d,
        'rain_intensity':      rain_1h / max(rain_7d, 0.1),
        'upstream_level_norm': upstream / t['d'],
        'day_sin':             day_sin,
        'day_cos':             day_cos,
        'hour_sin':            hour_sin,
    }
    X = _np.array([[feat.get(c, 0.0) for c in _BIHAR_RF_COLS]])
    Xs = _BIHAR_RF_SCALER.transform(X)
    sev = _BIHAR_RF_MODEL.predict(Xs)[0]
    prob = _BIHAR_RF_MODEL.predict_proba(Xs)[0]
    conf = dict(zip(_BIHAR_RF_MODEL.classes_, [round(float(p)*100, 1) for p in prob]))
    return {'severity': sev, 'confidence': conf, 'danger': t['d'], 'warning': t['w']}


# ── Helpers ─────────────────────────────────────────────────────────────────

def persist_prediction_record(input_data, result):
    try:
        input_payload = model_to_dict(input_data)
        station_name = str(input_payload.get("station") or "").strip() or None
        state_name = str(input_payload.get("state") or "Bihar").strip()
        rainfall_total = calculate_rainfall_total(input_payload)

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


# ============= MODEL ARTIFACTS ENDPOINTS =============

@router.get("/model-artifacts")
async def get_model_artifacts(predictor=None):
    ignored_legacy_artifacts = discover_legacy_artifacts_outside_store()
    if predictor:
        predictor.refresh_artifact_catalog()
        return {
            "status": "success",
            "base_dir": predictor.artifact_store_dir,
            "storage_backend": predictor.artifact_storage_backend,
            "artifact_count": len(predictor.artifact_catalog),
            "bundle_count": len(predictor.artifact_bundles),
            "default_bundle_key": predictor.default_bundle_key,
            "default_model": {
                "model": predictor.default_model_paths[0],
                "scaler": predictor.default_model_paths[1],
            },
            "bundles": predictor.artifact_bundles,
            "artifacts": predictor.artifact_catalog,
            "ignored_legacy_artifacts": ignored_legacy_artifacts,
        }
    artifacts = discover_model_artifacts()
    bundles = discover_model_bundles(artifacts)
    return {
        "status": "success",
        "artifact_count": len(artifacts),
        "bundle_count": len(bundles),
        "bundles": bundles,
        "artifacts": artifacts,
        "ignored_legacy_artifacts": ignored_legacy_artifacts,
    }


@router.get("/model-artifacts/{state_name}")
async def get_model_artifacts_for_state(state_name: str, predictor=None):
    if predictor:
        return {
            "status": "success",
            "selection": predictor.describe_state_model_artifacts(state_name),
        }
    return {"status": "success", "state": state_name, "message": "Predictor not initialized"}


@router.get("/model-metrics")
async def get_model_metrics(predictor=None):
    if predictor and hasattr(predictor, "get_metrics"):
        try:
            metrics = predictor.get_metrics()
            return {
                "status": "success",
                "model_trained": True,
                "algorithm": getattr(predictor, "algorithm_name", "Ensemble"),
                "bundle_key": getattr(predictor, "default_bundle_key", "default"),
                "metrics": metrics,
            }
        except Exception as exc:
            return {
                "status": "warning",
                "model_trained": True,
                "message": f"Metrics unavailable: {exc}",
                "metrics": {},
            }
    return {
        "status": "unavailable",
        "model_trained": False,
        "message": "Predictor not initialized or metrics not computed yet.",
        "metrics": {},
    }


# ============= STATE SEVERITY MATRIX ENDPOINTS =============

@router.get("/state-severity-matrix")
async def get_state_severity_matrix():
    return {
        "status": "success",
        "states": STATE_SEVERITY_MATRIX,
        "note": "CWC-calibrated thresholds with Option-A danger_level_override_guard active.",
    }


@router.get("/state-severity-matrix/{state_name}")
async def get_state_severity_matrix_for_state(state_name: str):
    return {
        "status": "success",
        "state": state_name,
        "matrix": get_state_severity_entry(state_name),
        "note": "CWC-calibrated thresholds with Option-A danger_level_override_guard active.",
    }


# ============= BULK RIVER SEVERITY ENDPOINT =============

@router.get("/api/river-severity")
async def get_river_severity(
    state: Optional[str] = None,
    district: Optional[str] = None,
    river: Optional[str] = None,
    min_risk_score: int = 0,
    limit: int = 200,
):
    """
    Bulk flood severity predictions for ALL live-level stations.

    Reads the same WRD Bihar + GloFAS + Matrix cache as /api/live-levels,
    runs FloodPredictor per city in a thread pool, and returns a
    severity-ranked list ready for the Flutter map/list screen.

    Fields per city:
      city, state, river_name, district,
      current_level, danger_level, warning_level,
      predicted_severity, risk_score, confidence_percent,
      will_breach_danger, peak_level_72h,
      algorithm, model_version,
      capacity_percent, trend, lat, lon, data_source, timestamp
    """
    # Import here to avoid circular imports — live_levels is a sibling router
    try:
        if _importlib_util.find_spec("backend") is not None:
            from backend.routers.live_levels import _build_all_levels
        else:
            from routers.live_levels import _build_all_levels  # type: ignore
    except Exception as e:
        return {"status": "error", "message": f"Could not load live_levels: {e}", "data": []}

    all_records = _build_all_levels()

    # Apply filters
    if state:
        norm = state.strip().lower()
        all_records = [r for r in all_records if norm in r.get("state", "").lower()]
    if district:
        dn = district.strip().lower()
        all_records = [r for r in all_records if dn in (r.get("district") or "").lower()]
    if river:
        rn = river.strip().lower()
        all_records = [r for r in all_records if rn in r.get("river_name", "").lower()]

    # Run predictor per city in thread pool (non-blocking)
    loop = asyncio.get_event_loop()
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        futures = [
            loop.run_in_executor(pool, _severity_from_live_record, rec)
            for rec in all_records
        ]
        sev_results = await asyncio.gather(*futures)

    results: List[Dict[str, Any]] = []
    for rec, sev in zip(all_records, sev_results):
        score = sev.get("risk_score") or 0
        if score < min_risk_score:
            continue
        results.append({
            # Identity
            "city":              rec.get("city"),
            "state":             rec.get("state"),
            "river_name":        rec.get("river_name"),
            "district":          rec.get("district"),
            "station":           rec.get("station"),
            "lat":               rec.get("lat"),
            "lon":               rec.get("lon"),
            # Live levels
            "current_level":     rec.get("current_level"),
            "danger_level":      rec.get("danger_level"),
            "warning_level":     rec.get("warning_level"),
            "capacity_percent":  rec.get("capacity_percent"),
            "trend":             rec.get("trend"),
            # ML prediction
            "predicted_severity":  sev.get("predicted_severity"),
            "risk_score":          sev.get("risk_score"),
            "confidence_percent":  sev.get("confidence_percent"),
            "will_breach_danger":  sev.get("will_breach_danger"),
            "peak_level_72h":      sev.get("peak_level_72h"),
            "algorithm":           sev.get("algorithm"),
            "model_version":       sev.get("model_version"),
            # Provenance
            "data_source":     rec.get("data_source"),
            "timestamp":       rec.get("timestamp"),
        })

    # Sort: highest risk first
    _sev_rank = {"CRITICAL": 4, "SEVERE": 3, "MODERATE": 2, "LOW": 1, None: 0}
    results.sort(
        key=lambda x: (
            _sev_rank.get(x.get("predicted_severity"), 0),
            x.get("risk_score") or 0,
        ),
        reverse=True,
    )
    results = results[:limit]

    critical_count  = sum(1 for r in results if r["predicted_severity"] == "CRITICAL")
    severe_count    = sum(1 for r in results if r["predicted_severity"] == "SEVERE")
    moderate_count  = sum(1 for r in results if r["predicted_severity"] == "MODERATE")
    low_count       = sum(1 for r in results if r["predicted_severity"] == "LOW")

    from .dependencies import current_timestamp_iso
    return {
        "status":         "success",
        "total":          len(results),
        "critical_count": critical_count,
        "severe_count":   severe_count,
        "moderate_count": moderate_count,
        "low_count":      low_count,
        "timestamp":      current_timestamp_iso(),
        "data":           results,
    }


# ============= PREDICTION ENDPOINT (LEGACY) =============

@router.post("/predict/legacy")
async def predict_flood_legacy(
    input_data: FloodPredictionInput, predictor=None, cwc_scraper=None
):
    try:
        source_policy = get_source_policy_payload()
        data_source = str(source_policy["prediction_data_source"])
        river_level_m: float | None = None

        if source_policy.get("allow_live_cwc_in_app") and cwc_scraper:
            try:
                live_data = await asyncio.to_thread(
                    cwc_scraper.get_live_river_level,
                    input_data.station or "Kolhapur",
                )
                if live_data.get("status") in ["success", "success_fallback"]:
                    data_source = "Live CWC Data"
                    river_level_m = live_data.get("current_level_m")
            except Exception as e:
                print(f"\u26a0\ufe0f Live CWC fetch failed, falling back: {e}")

        _legacy_effective_entry = build_effective_state_entry(
            state_name=input_data.state,
            station_telemetry=None,
        )

        if predictor:
            result = await asyncio.to_thread(
                predictor.predict_flood,
                input_data,
                source=data_source,
                river_level_m=river_level_m,
                state_entry_override=_legacy_effective_entry,
            )
        else:
            try:
                result = await asyncio.to_thread(
                    _run_flood_predictor, input_data, data_source, _legacy_effective_entry
                )
            except Exception as fp_exc:
                print(f"\u26a0\ufe0f FloodPredictor failed in legacy: {fp_exc}")
                result = {
                    "severity": "MODERATE",
                    "confidence_percent": 75.0,
                    "probabilities": {"SEVERE": 25, "MODERATE": 75, "LOW": 0, "CRITICAL": 0},
                    "alert": "\u26a0\ufe0f",
                    "algorithm": "Fallback",
                    "data_source": data_source,
                    "model_trained": False,
                    "risk_score": 50,
                    "state": input_data.state,
                }

        result["source_policy"] = source_policy
        persist_prediction_record(input_data, result)
        return result

    except Exception as e:
        return {
            "status": "error",
            "message": str(e),
            "severity": "UNKNOWN",
            "risk_score": 0,
            "source_policy": get_source_policy_payload(),
        }


# ============= PREDICTION ENDPOINT V2 (PIPELINE AUTO-FILL) =============

@router.post("/predict/v2")
async def predict_flood_v2(
    input_data: FloodPredictionInput, predictor=None, cwc_scraper=None
):
    try:
        source_policy = get_source_policy_payload()
        data_source = str(source_policy["prediction_data_source"])
        river_level_m: float | None = None
        autofill_applied = False
        pipeline_meta: dict | None = None

        input_dict = model_to_dict(input_data)
        enriched = pipeline_autofill_predict_input(
            input_dict,
            state_name=input_data.state,
            station_name=input_data.station,
        )
        pipeline_meta = enriched.pop("_pipeline_autofill", None)
        if pipeline_meta and pipeline_meta.get("applied"):
            autofill_applied = True
            data_source = "OperationalDataPipeline + " + data_source
            input_data = input_data.model_copy(update={
                k: v for k, v in enriched.items()
                if k in FloodPredictionInput.model_fields and v is not None
            })
            features = get_pipeline_features(input_data.state, input_data.station)
            if features:
                rl = features.get("river_level_m")
                try:
                    river_level_m = float(rl) if rl is not None else None
                except (TypeError, ValueError):
                    river_level_m = None

        if cwc_scraper and river_level_m is None:
            try:
                station_query = input_data.station or input_data.state
                live_data = await asyncio.to_thread(
                    cwc_scraper.get_live_river_level,
                    station_query,
                )
                if live_data.get("status") in ["success", "success_fallback"]:
                    river_level_m = live_data.get("current_level_m")
                    if river_level_m and input_data.Peak_Flood_Level_m == 8.5:
                        input_data = input_data.model_copy(
                            update={"Peak_Flood_Level_m": float(river_level_m)}
                        )
                        if not autofill_applied:
                            autofill_applied = True
                        data_source = "Live CWC (real-time override)"
            except Exception as e:
                print(f"\u26a0\ufe0f V2 CWC auto-fill failed: {e}")

        _telemetry_payload: dict | None = None
        try:
            if _importlib_util.find_spec("backend") is not None:
                from backend.cwc_scraper import CWCScraper as _CWCScraper
            else:
                from cwc_scraper import CWCScraper as _CWCScraper  # type: ignore
            _ts = _CWCScraper()
            _raw = _ts.get_state_telemetry(input_data.state)
            if isinstance(_raw, dict) and _raw.get("data"):
                _telemetry_payload = _raw
        except Exception:
            pass

        # ── Bihar RF override ────────────────────────────────────────────
        bihar_rf = None
        if str(input_data.state or '').lower() == 'bihar' and input_data.station:
            _rl = river_level_m or float(input_data.Peak_Flood_Level_m or 0)
            bihar_rf = _bihar_rf_predict(
                station   = input_data.station,
                level_m   = _rl,
                rain_1h   = float(input_data.T1d or 2.0),
                rain_3d   = float(input_data.T3d or 10.0),
                rain_7d   = float(input_data.T7d or 25.0),
            )

        _best_node = select_best_station_node(
            state_name=input_data.state,
            station_name=input_data.station,
            telemetry_payload=_telemetry_payload,
        )
        _effective_entry = build_effective_state_entry(
            state_name=input_data.state,
            station_telemetry=_best_node,
        )

        if predictor:
            result = await asyncio.to_thread(
                predictor.predict_flood,
                input_data,
                source=data_source,
                river_level_m=river_level_m,
                state_entry_override=_effective_entry,
            )
        else:
            try:
                result = await asyncio.to_thread(
                    _run_flood_predictor, input_data, data_source, _effective_entry
                )
            except Exception as fp_exc:
                print(f"\u26a0\ufe0f FloodPredictor failed in v2: {fp_exc}")
                result = {
                    "severity": "MODERATE",
                    "confidence_percent": 75.0,
                    "probabilities": {"SEVERE": 25, "MODERATE": 75, "LOW": 0, "CRITICAL": 0},
                    "alert": "\u26a0\ufe0f",
                    "algorithm": "Fallback",
                    "data_source": data_source,
                    "model_trained": False,
                    "risk_score": 50,
                    "state": input_data.state,
                }

        # ── Override with Bihar RF if available ─────────────────────────
        if bihar_rf is not None:
            result["severity"]           = bihar_rf["severity"]
            result["algorithm"]          = "Bihar-RF-v2"
            result["confidence_percent"] = max(bihar_rf["confidence"].values())
            result["probabilities"]      = bihar_rf["confidence"]
            result["danger_level_m"]     = bihar_rf["danger"]
            result["warning_level_m"]    = bihar_rf["warning"]
            risk_map = {"LOW": 15, "MODERATE": 45, "SEVERE": 70, "CRITICAL": 90}
            result["risk_score"]         = risk_map.get(bihar_rf["severity"], 50)

        result["source_policy"] = source_policy
        result["autofill_applied"] = autofill_applied
        result["live_river_level_m"] = river_level_m
        result["pipeline_context"] = pipeline_meta

        persist_prediction_record(input_data, result)
        return result

    except Exception as e:
        return {
            "status": "error",
            "message": str(e),
            "severity": "UNKNOWN",
            "risk_score": 0,
            "source_policy": get_source_policy_payload(),
        }


@router.get("/prediction-history")
async def get_prediction_history(state: str | None = None, limit: int = 50):
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
