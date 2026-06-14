"""
Live Levels router: Serves /api/live-levels and /api/critical-alerts
for the OpsFlood Flutter app.

Data priority order:
  1. WRD Bihar BeFIQR (31 real gauge stations with HFL + DL) — Bihar only
  2. GloFAS Open-Meteo cache — Bihar: ALL per-city stations (115+)
                             — other states: best discharge per state
  3. STATE_SEVERITY_MATRIX fallback — states with no live data

Severity (Step B):
  Every record returned by _build_all_levels_with_severity() carries:
    predicted_severity, risk_score, confidence_percent,
    will_breach_danger, peak_level_72h, algorithm, model_version
  injected by _attach_predicted_severity() which calls FloodPredictor
  per city in a thread pool.

Risk thresholds (Bihar ASL gauges, aligned with WRD Bihar definitions):
  CRITICAL  — above_dl >= 0       (at or above danger level)
  HIGH      — above_dl in [-3, 0) (within WRD WARNING zone, <3 m below DL)
  MODERATE  — above_dl in [-6,-3) (approaching, 3-6 m below DL)
  LOW       — above_dl < -6       (well below danger level)
"""

from fastapi import APIRouter
from typing import Any, Dict, List, Optional
import sys
import concurrent.futures
import asyncio

from .dependencies import (
    STATE_SEVERITY_MATRIX,
    current_timestamp_iso,
)

router = APIRouter(tags=["live-levels"])


# ---------------------------------------------------------------------------
# Cache accessors
# ---------------------------------------------------------------------------

def _get_glofas_cache() -> List[Dict[str, Any]]:
    """Returns the full flat list from GLOFAS_STATION_CACHE (all cities)."""
    try:
        for mod_name in ("backend.app", "app"):
            mod = sys.modules.get(mod_name)
            if mod is not None:
                cache = getattr(mod, "GLOFAS_STATION_CACHE", None)
                if isinstance(cache, list) and len(cache) > 0:
                    return cache
    except Exception:
        pass
    try:
        for mod_name in ("backend.cwc_scraper", "cwc_scraper"):
            mod = sys.modules.get(mod_name)
            if mod is not None:
                stations = getattr(mod, "_cached_stations", None)
                if isinstance(stations, list) and len(stations) > 0:
                    return stations
    except Exception:
        pass
    return []


def _get_wrd_bihar_stations() -> List[Dict[str, Any]]:
    try:
        for mod_name in ("backend.routers.wrd_bihar", "routers.wrd_bihar"):
            mod = sys.modules.get(mod_name)
            if mod is not None:
                cache     = getattr(mod, "_CACHE", None)
                cache_key = getattr(mod, "_CACHE_KEY", None)
                if cache is not None and cache_key and cache_key in cache:
                    return cache[cache_key].get("stations", [])
    except Exception:
        pass
    return []


# ---------------------------------------------------------------------------
# Risk / status helpers
# ---------------------------------------------------------------------------

def _risk_from_capacity(cap: float) -> str:
    if cap >= 100: return "CRITICAL"
    if cap >= 85:  return "HIGH"
    if cap >= 70:  return "MODERATE"
    return "LOW"


def _risk_from_discharge(discharge: float, danger_q: float, warning_q: float) -> str:
    if danger_q > 0 and discharge >= danger_q:         return "CRITICAL"
    if warning_q > 0 and discharge >= warning_q:       return "HIGH"
    if warning_q > 0 and discharge >= warning_q * 0.7: return "MODERATE"
    return "LOW"


def _risk_from_above_dl(above_dl: Optional[float], wrd_status: str) -> str:
    if above_dl is not None:
        if above_dl >= 0:    return "CRITICAL"
        if above_dl >= -3.0: return "HIGH"
        if above_dl >= -6.0: return "MODERATE"
        return "LOW"
    return {
        "CRITICAL": "CRITICAL",
        "DANGER":   "HIGH",
        "WARNING":  "HIGH",
        "NORMAL":   "LOW",
        "UNKNOWN":  "LOW",
    }.get((wrd_status or "").upper(), "LOW")


def _capacity_from_discharge(discharge: float, danger_q: float) -> float:
    if danger_q <= 0:
        return 50.0
    return min(round(discharge / danger_q * 100.0, 1), 130.0)


def _capacity_from_asl_levels(
    current_m: Optional[float],
    danger_m: float,
    hfl_m: Optional[float],
    above_dl: Optional[float],
) -> float:
    if above_dl is not None:
        span = 10.0
        pct  = 100.0 + (above_dl / span * 100.0)
        return round(min(max(pct, 0.0), 130.0), 1)
    if current_m is not None and danger_m > 0:
        span  = 10.0
        above = current_m - danger_m
        pct   = 100.0 + (above / span * 100.0)
        return round(min(max(pct, 0.0), 130.0), 1)
    return 50.0


def _capacity_from_glofas_station(s: Dict[str, Any], base_safe: float, base_danger: float) -> float:
    river_level  = float(s.get("river_level")  or s.get("current_level_m") or 0.0)
    warning_lv   = float(s.get("warning_level") or s.get("warning_level_m") or base_safe)
    danger_lv    = float(s.get("danger_level")  or s.get("danger_level_m")  or base_danger)
    if danger_lv <= 0:
        return 50.0
    pct = (river_level - warning_lv) / max(danger_lv - warning_lv, 0.01) * 100.0 + 50.0
    return round(min(max(pct, 0.0), 130.0), 1)


def _risk_from_glofas_station(s: Dict[str, Any], base_safe: float, base_danger: float) -> str:
    status = (s.get("status") or "").upper()
    if status == "CRITICAL":
        return "CRITICAL"
    if status == "WARNING":
        return "HIGH"
    cap = _capacity_from_glofas_station(s, base_safe, base_danger)
    return _risk_from_capacity(cap)


def _status_from_risk(risk: str) -> str:
    return {"CRITICAL": "RISING", "HIGH": "RISING",
            "MODERATE": "STABLE", "LOW": "STABLE"}.get(risk, "STABLE")


def _alert_from_risk(risk: str) -> str:
    return {"CRITICAL": "\U0001f6a8", "HIGH": "\u26a0\ufe0f",
            "MODERATE": "\U0001f4ca", "LOW": "\u2705"}.get(risk, "\U0001f4ca")


# ---------------------------------------------------------------------------
# Base level tables
# ---------------------------------------------------------------------------

_BASE_LEVELS: Dict[str, Dict[str, float]] = {
    "maharashtra":      {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 78.0},
    "kerala":           {"safe": 1.8, "warning": 2.8, "danger": 4.0,  "cap": 74.0},
    "assam":            {"safe": 3.0, "warning": 5.0, "danger": 7.5,  "cap": 88.0},
    "bihar":            {"safe": 4.0, "warning": 6.0, "danger": 8.0,  "cap": 86.0},
    "odisha":           {"safe": 3.5, "warning": 5.5, "danger": 7.0,  "cap": 65.0},
    "west_bengal":      {"safe": 3.0, "warning": 5.0, "danger": 6.5,  "cap": 62.0},
    "uttar_pradesh":    {"safe": 4.5, "warning": 6.5, "danger": 9.0,  "cap": 55.0},
    "andhra_pradesh":   {"safe": 3.0, "warning": 4.5, "danger": 6.0,  "cap": 73.0},
    "telangana":        {"safe": 2.5, "warning": 4.0, "danger": 5.5,  "cap": 60.0},
    "karnataka":        {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 55.0},
    "gujarat":          {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 42.0},
    "rajasthan":        {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 38.0},
    "madhya_pradesh":   {"safe": 3.0, "warning": 4.5, "danger": 6.0,  "cap": 52.0},
    "chhattisgarh":     {"safe": 2.5, "warning": 4.0, "danger": 5.5,  "cap": 48.0},
    "jharkhand":        {"safe": 2.5, "warning": 4.0, "danger": 5.5,  "cap": 50.0},
    "punjab":           {"safe": 2.5, "warning": 4.0, "danger": 5.5,  "cap": 54.0},
    "haryana":          {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 46.0},
    "himachal_pradesh": {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 52.0},
    "uttarakhand":      {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 52.0},
    "tamil_nadu":       {"safe": 2.0, "warning": 3.5, "danger": 5.0,  "cap": 48.0},
    "arunachal_pradesh":{"safe": 3.0, "warning": 5.0, "danger": 7.5,  "cap": 67.0},
    "manipur":          {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 44.0},
    "meghalaya":        {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 48.0},
    "nagaland":         {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 38.0},
    "mizoram":          {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 38.0},
    "tripura":          {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 46.0},
    "sikkim":           {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 58.0},
    "goa":              {"safe": 1.5, "warning": 2.5, "danger": 3.5,  "cap": 32.0},
    "delhi":            {"safe": 2.5, "warning": 4.0, "danger": 6.0,  "cap": 50.0},
    "jammu_and_kashmir":{"safe": 2.0, "warning": 3.5, "danger": 5.5,  "cap": 62.0},
}

_CITY_RIVER_MAP: Dict[str, tuple] = {
    "maharashtra":      ("Kolhapur",   "Panchganga"),
    "kerala":           ("Kochi",      "Periyar"),
    "assam":            ("Guwahati",   "Brahmaputra"),
    "bihar":            ("Patna",      "Ganga"),
    "odisha":           ("Cuttack",    "Mahanadi"),
    "west_bengal":      ("Kolkata",    "Hooghly"),
    "uttar_pradesh":    ("Varanasi",   "Ganga"),
    "andhra_pradesh":   ("Vijayawada", "Krishna"),
    "telangana":        ("Hyderabad",  "Musi"),
    "karnataka":        ("Mysuru",     "Kaveri"),
    "gujarat":          ("Vadodara",   "Vishwamitri"),
    "rajasthan":        ("Kota",       "Chambal"),
    "madhya_pradesh":   ("Jabalpur",   "Narmada"),
    "chhattisgarh":     ("Raipur",     "Mahanadi"),
    "jharkhand":        ("Dhanbad",    "Damodar"),
    "punjab":           ("Ludhiana",   "Sutlej"),
    "haryana":          ("Ambala",     "Ghaggar"),
    "himachal_pradesh": ("Mandi",      "Beas"),
    "uttarakhand":      ("Haridwar",   "Ganga"),
    "tamil_nadu":       ("Chennai",    "Adyar"),
    "arunachal_pradesh":("Pasighat",   "Brahmaputra"),
    "manipur":          ("Imphal",     "Imphal River"),
    "meghalaya":        ("Shillong",   "Umiam"),
    "nagaland":         ("Dimapur",    "Dhansiri"),
    "mizoram":          ("Aizawl",     "Tlawng"),
    "tripura":          ("Agartala",   "Haora"),
    "sikkim":           ("Gangtok",    "Teesta"),
    "goa":              ("Panaji",     "Mandovi"),
    "delhi":            ("New Delhi",  "Yamuna"),
    "jammu_and_kashmir":("Srinagar",   "Jhelum"),
}

_STATE_DISPLAY: Dict[str, str] = {
    "maharashtra": "Maharashtra", "kerala": "Kerala", "assam": "Assam",
    "bihar": "Bihar", "odisha": "Odisha", "west_bengal": "West Bengal",
    "uttar_pradesh": "Uttar Pradesh", "andhra_pradesh": "Andhra Pradesh",
    "telangana": "Telangana", "karnataka": "Karnataka", "gujarat": "Gujarat",
    "rajasthan": "Rajasthan", "madhya_pradesh": "Madhya Pradesh",
    "chhattisgarh": "Chhattisgarh", "jharkhand": "Jharkhand",
    "punjab": "Punjab", "haryana": "Haryana",
    "himachal_pradesh": "Himachal Pradesh", "uttarakhand": "Uttarakhand",
    "tamil_nadu": "Tamil Nadu", "arunachal_pradesh": "Arunachal Pradesh",
    "manipur": "Manipur", "meghalaya": "Meghalaya", "nagaland": "Nagaland",
    "mizoram": "Mizoram", "tripura": "Tripura", "sikkim": "Sikkim",
    "goa": "Goa", "delhi": "Delhi", "jammu_and_kashmir": "Jammu and Kashmir",
}


def _normalise_state_key(s: str) -> str:
    return s.strip().lower().replace(" ", "_").replace("-", "_")


# ---------------------------------------------------------------------------
# WRD Bihar builder
# ---------------------------------------------------------------------------

def _build_levels_from_wrd_bihar(
    wrd_stations: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    now_iso = current_timestamp_iso()
    result: List[Dict[str, Any]] = []

    for s in wrd_stations:
        city       = str(s.get("station") or "").strip()
        river      = str(s.get("river") or "Unknown").strip()
        district   = str(s.get("district") or "Bihar").strip()
        lat        = s.get("lat", 25.8)
        lon        = s.get("lon", 85.4)
        current_m  = s.get("current_level_m")
        danger_m   = s.get("danger_level_m") or 0.0
        hfl_m      = s.get("hfl_m")
        above_dl   = s.get("above_below_danger_m")
        change_24h = s.get("change_24h_m")
        trend      = s.get("trend", "\u2014")
        wrd_status = s.get("status", "UNKNOWN")
        source_raw = s.get("source", "WRD_BIHAR_BEFIQR")
        last_update= s.get("last_update", now_iso)

        if not city:
            continue

        risk     = _risk_from_above_dl(above_dl, wrd_status)
        capacity = _capacity_from_asl_levels(current_m, danger_m, hfl_m, above_dl)
        status   = _status_from_risk(risk)
        alert    = _alert_from_risk(risk)
        safe_display    = round(danger_m - 10.0, 2) if danger_m > 10 else 0.0
        warning_display = round(danger_m - 3.0,  2) if danger_m > 3  else danger_m

        result.append({
            "city":                 city,
            "state":                "Bihar",
            "river_name":           river,
            "station":              city,
            "current_level":        current_m,
            "safe_level":           safe_display,
            "warning_level":        warning_display,
            "danger_level":         danger_m,
            "capacity_percent":     capacity,
            "risk_level":           risk,
            "status":               status,
            "alert":                alert,
            "flow_rate":            None,
            "lat":                  lat,
            "lon":                  lon,
            "data_source":          "WRD_BIHAR_BEFIQR" if "FALLBACK" not in source_raw else "WRD_BIHAR_FALLBACK",
            "timestamp":            last_update,
            "hfl_m":                hfl_m,
            "district":             district,
            "above_below_danger_m": above_dl,
            "change_24h_m":         change_24h,
            "trend":                trend,
            "wrd_status":           wrd_status,
            # Severity fields — filled by _attach_predicted_severity
            "predicted_severity":   None,
            "risk_score":           None,
            "confidence_percent":   None,
            "will_breach_danger":   None,
            "peak_level_72h":       None,
            "algorithm":            None,
            "model_version":        None,
        })

    return result


# ---------------------------------------------------------------------------
# GloFAS Bihar — ALL per-city stations
# ---------------------------------------------------------------------------

def _build_levels_from_glofas_bihar(
    glofas_cache: List[Dict[str, Any]],
    wrd_city_names: set,
) -> List[Dict[str, Any]]:
    now_iso = current_timestamp_iso()
    base    = _BASE_LEVELS.get("bihar", {"safe": 4.0, "warning": 6.0, "danger": 8.0})
    result: List[Dict[str, Any]] = []
    seen_cities: set = set()

    for s in glofas_cache:
        state_raw = (s.get("state") or s.get("state_name") or "").strip().lower()
        if state_raw != "bihar":
            continue

        city = str(s.get("station") or s.get("city") or "").strip()
        if not city:
            continue
        city_key = city.lower()
        if city_key in seen_cities or city_key in wrd_city_names:
            continue
        seen_cities.add(city_key)

        river      = str(s.get("river") or s.get("river_name") or "River").strip()
        district   = str(s.get("district") or "").strip()
        lat        = s.get("lat")
        lon        = s.get("lon")
        river_lv   = float(s.get("river_level") or s.get("current_level_m") or 0.0)
        warning_lv = float(s.get("warning_level") or s.get("warning_level_m") or base["warning"])
        danger_lv  = float(s.get("danger_level")  or s.get("danger_level_m")  or base["danger"])
        safe_lv    = float(s.get("safe_level")    or s.get("safe_level_m")    or base["safe"])
        discharge  = float(s.get("river_discharge_m3s") or s.get("flow_rate") or 0.0)
        trend      = str(s.get("trend") or "STEADY")
        last_upd   = str(s.get("last_update") or now_iso)

        capacity = _capacity_from_glofas_station(s, base["safe"], base["danger"])
        risk     = _risk_from_glofas_station(s, base["safe"], base["danger"])
        status   = _status_from_risk(risk)
        alert    = _alert_from_risk(risk)

        result.append({
            "city":             city,
            "state":            "Bihar",
            "river_name":       river,
            "station":          city,
            "district":         district,
            "current_level":    round(river_lv, 3),
            "safe_level":       round(safe_lv, 3),
            "warning_level":    round(warning_lv, 3),
            "danger_level":     round(danger_lv, 3),
            "river_discharge":  discharge,
            "capacity_percent": capacity,
            "risk_level":       risk,
            "status":           status,
            "alert":            alert,
            "flow_rate":        discharge if discharge > 0 else None,
            "trend":            trend,
            "lat":              lat,
            "lon":              lon,
            "data_source":      "OPEN_METEO_GLOFAS",
            "timestamp":        last_upd,
            # Severity fields — filled by _attach_predicted_severity
            "predicted_severity":   None,
            "risk_score":           None,
            "confidence_percent":   None,
            "will_breach_danger":   None,
            "peak_level_72h":       None,
            "algorithm":            None,
            "model_version":        None,
        })

    result.sort(key=lambda x: x["capacity_percent"], reverse=True)
    return result


# ---------------------------------------------------------------------------
# GloFAS other states — best discharge per state
# ---------------------------------------------------------------------------

def _build_station_record(
    station: Dict[str, Any],
    now_iso: str,
    state_key: str,
) -> Dict[str, Any]:
    city      = str(station.get("station_name") or station.get("city") or "").strip()
    state     = str(station.get("state_name")   or station.get("state") or "").strip()
    river     = str(station.get("river_name")   or station.get("river") or "").strip()
    discharge = float(station.get("river_discharge") or station.get("river_discharge_m3s") or 0.0)
    warning_q = float(station.get("warning_discharge") or 0.0)
    danger_q  = float(station.get("danger_discharge")  or 0.0)
    base      = _BASE_LEVELS.get(state_key, {"safe": 2.0, "warning": 3.5, "danger": 5.0})
    current_m = float(station.get("current_level_m") or station.get("river_level") or 0.0)
    warning_m = float(station.get("warning_level_m") or station.get("warning_level") or base["warning"])
    danger_m  = float(station.get("danger_level_m")  or station.get("danger_level")  or base["danger"])
    safe_m    = float(station.get("safe_level_m")    or base["safe"])

    if current_m == 0.0 and discharge > 0 and danger_q > 0:
        current_m = round(safe_m + (danger_m - safe_m) * (discharge / danger_q), 2)
        current_m = min(current_m, danger_m * 1.5)

    capacity = _capacity_from_discharge(discharge, danger_q) if danger_q > 0 \
               else min(round((current_m - safe_m) / max(danger_m - safe_m, 0.01) * 100, 1), 130.0)
    risk = str(station.get("risk_level") or "").upper() or \
           _risk_from_discharge(discharge, danger_q, warning_q)
    ts = str(station.get("timestamp") or now_iso)

    return {
        "city":             city,
        "state":            state,
        "river_name":       river,
        "station":          city,
        "current_level":    current_m,
        "safe_level":       safe_m,
        "warning_level":    warning_m,
        "danger_level":     danger_m,
        "river_discharge":  discharge,
        "capacity_percent": capacity,
        "risk_level":       risk,
        "status":           _status_from_risk(risk),
        "alert":            _alert_from_risk(risk),
        "flow_rate":        discharge if discharge > 0 else None,
        "lat":              station.get("lat"),
        "lon":              station.get("lon"),
        "data_source":      "OPEN_METEO_GLOFAS",
        "timestamp":        ts,
        "_discharge":       discharge,
        # Severity fields
        "predicted_severity":   None,
        "risk_score":           None,
        "confidence_percent":   None,
        "will_breach_danger":   None,
        "peak_level_72h":       None,
        "algorithm":            None,
        "model_version":        None,
    }


def _build_levels_from_glofas_other_states(
    glofas_cache: List[Dict],
    exclude_state_keys: set,
) -> tuple:
    now_iso = current_timestamp_iso()
    best_by_state: Dict[str, Dict[str, Any]] = {}

    for station in glofas_cache:
        city  = str(station.get("station_name") or station.get("city") or "").strip()
        state = str(station.get("state_name")   or station.get("state") or "").strip()
        if not city or not state:
            continue
        state_key = _normalise_state_key(state)
        if state_key in exclude_state_keys or state_key == "bihar":
            continue
        record    = _build_station_record(station, now_iso, state_key)
        discharge = record["_discharge"]
        existing  = best_by_state.get(state_key)
        if existing is None or discharge > existing["_discharge"]:
            best_by_state[state_key] = record

    result: List[Dict[str, Any]] = []
    for record in best_by_state.values():
        record.pop("_discharge", None)
        result.append(record)
    return result, set(best_by_state.keys())


# ---------------------------------------------------------------------------
# Matrix fallback
# ---------------------------------------------------------------------------

def _build_levels_from_matrix(exclude_state_keys: set) -> List[Dict[str, Any]]:
    now_iso = current_timestamp_iso()
    result: List[Dict[str, Any]] = []
    seen: set = set()

    for state_key, entry in STATE_SEVERITY_MATRIX.items():
        if state_key in seen or state_key in exclude_state_keys:
            continue
        seen.add(state_key)
        base          = _BASE_LEVELS.get(state_key, {"safe": 2.0, "warning": 3.5, "danger": 5.0, "cap": 50.0})
        city, river   = _CITY_RIVER_MAP.get(state_key, ("Unknown", "River"))
        state_display = _STATE_DISPLAY.get(state_key, state_key.replace("_", " ").title())
        severity      = entry.get("default_severity", "MODERATE").upper()
        capacity      = {"CRITICAL": 105.0, "HIGH": 88.0, "MODERATE": 55.0, "LOW": 35.0}.get(severity, base.get("cap", 50.0))
        risk          = _risk_from_capacity(capacity)
        danger_m      = float(entry.get("danger_threshold_m")  or base["danger"])
        warning_m     = float(entry.get("warning_threshold_m") or base["warning"])
        safe_m        = base["safe"]
        current       = round(safe_m + (danger_m - safe_m) * min(capacity / 100.0, 1.3), 2)

        result.append({
            "city":             city,
            "state":            state_display,
            "river_name":       river,
            "station":          city,
            "current_level":    current,
            "safe_level":       safe_m,
            "warning_level":    warning_m,
            "danger_level":     danger_m,
            "capacity_percent": round(capacity, 1),
            "risk_level":       risk,
            "status":           _status_from_risk(risk),
            "alert":            _alert_from_risk(risk),
            "flow_rate":        None,
            "data_source":      "STATE_SEVERITY_MATRIX",
            "timestamp":        now_iso,
            "predicted_severity":   None,
            "risk_score":           None,
            "confidence_percent":   None,
            "will_breach_danger":   None,
            "peak_level_72h":       None,
            "algorithm":            None,
            "model_version":        None,
        })

    result.sort(key=lambda x: x["capacity_percent"], reverse=True)
    return result


# ---------------------------------------------------------------------------
# Master merge — raw levels (no severity yet)
# ---------------------------------------------------------------------------

def _build_all_levels() -> List[Dict[str, Any]]:
    """Returns raw live-level records WITHOUT predicted_severity filled in.
    Call _build_all_levels_with_severity() from async route handlers instead.
    """
    covered: set = set()
    all_levels: List[Dict[str, Any]] = []

    wrd_stations   = _get_wrd_bihar_stations()
    wrd_city_names: set = set()
    if wrd_stations:
        bihar_wrd = _build_levels_from_wrd_bihar(wrd_stations)
        all_levels.extend(bihar_wrd)
        wrd_city_names = {r["city"].lower() for r in bihar_wrd}
        covered.add("bihar")
        print(f"[live_levels] \u2705 WRD Bihar: {len(bihar_wrd)} stations")
    else:
        print("[live_levels] \u26a0\ufe0f  WRD Bihar cache empty")

    glofas_cache = _get_glofas_cache()
    if glofas_cache:
        bihar_glofas = _build_levels_from_glofas_bihar(glofas_cache, wrd_city_names)
        all_levels.extend(bihar_glofas)
        covered.add("bihar")
        print(f"[live_levels] \u2705 GloFAS Bihar cities: {len(bihar_glofas)}")

        other_levels, other_covered = _build_levels_from_glofas_other_states(
            glofas_cache, exclude_state_keys=covered
        )
        all_levels.extend(other_levels)
        covered.update(other_covered)
        print(f"[live_levels] \u2705 GloFAS other states: {len(other_levels)}")
    else:
        print("[live_levels] \u26a0\ufe0f  GloFAS cache empty")

    matrix_levels = _build_levels_from_matrix(exclude_state_keys=covered)
    all_levels.extend(matrix_levels)
    print(f"[live_levels] Matrix fallback: {len(matrix_levels)} states")

    all_levels.sort(key=lambda x: x["capacity_percent"], reverse=True)
    return all_levels


# ---------------------------------------------------------------------------
# Step B — Attach predicted_severity to every record (async, thread pool)
# ---------------------------------------------------------------------------

def _attach_predicted_severity_sync(record: Dict[str, Any]) -> Dict[str, Any]:
    """Synchronous wrapper — called inside thread pool."""
    try:
        # Lazy import to avoid circular dependency at module load time
        import importlib.util as _iu
        if _iu.find_spec("backend") is not None:
            from backend.routers.predict import _severity_from_live_record
        else:
            from routers.predict import _severity_from_live_record  # type: ignore
        sev = _severity_from_live_record(record)
    except Exception as exc:
        print(f"[live_levels] severity attach failed for {record.get('city')}: {exc}")
        sev = {
            "predicted_severity": None, "risk_score": None,
            "confidence_percent": None, "will_breach_danger": None,
            "peak_level_72h": None, "algorithm": None, "model_version": None,
        }
    out = dict(record)
    out.update(sev)
    return out


async def _build_all_levels_with_severity() -> List[Dict[str, Any]]:
    """Builds all levels then enriches each record with ML severity in parallel."""
    raw_levels = _build_all_levels()
    loop = asyncio.get_event_loop()
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        futures = [
            loop.run_in_executor(pool, _attach_predicted_severity_sync, rec)
            for rec in raw_levels
        ]
        enriched = await asyncio.gather(*futures)
    return list(enriched)


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@router.get("/api/live-levels")
async def get_live_levels(
    state: Optional[str] = None,
    limit: int = 200,
    river: Optional[str] = None,
    district: Optional[str] = None,
    with_severity: bool = True,   # set False to skip ML inference for speed
):
    if with_severity:
        levels = await _build_all_levels_with_severity()
    else:
        levels = _build_all_levels()

    if state:
        norm   = state.strip().lower()
        levels = [l for l in levels if norm in l["state"].lower()]
    if river:
        rn = river.strip().lower()
        levels = [l for l in levels if rn in l.get("river_name", "").lower()]
    if district:
        dn = district.strip().lower()
        levels = [l for l in levels if dn in (l.get("district") or "").lower()]

    levels = levels[:limit]

    wrd_count    = sum(1 for l in levels if "WRD_BIHAR" in l.get("data_source", ""))
    glofas_count = sum(1 for l in levels if l.get("data_source") == "OPEN_METEO_GLOFAS")
    matrix_count = len(levels) - wrd_count - glofas_count
    bihar_count  = sum(1 for l in levels if l.get("state", "").lower() == "bihar")

    if wrd_