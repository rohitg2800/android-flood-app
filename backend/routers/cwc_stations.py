"""
backend/routers/cwc_stations.py
--------------------------------
GET /api/cwc-stations?codes=KOSI-BIRPUR,GANDAK-HAJIPUR,...

Bridges the internal CWC station-code format used by the Flutter app
(DataFetchEngine) to the existing CWC FFS scraper data.

Code format:  <RIVER>-<STATION_SLUG>   e.g. KOSI-BIRPUR

Strategy (in order):
  1. Look up the code in KNOWN_STATIONS → get canonical station name
  2. Try to match that name in the live CWC FFS HTML scrape
     (via fuzzy match on station_name field)
  3. If not found in FFS data, fall back to the hardcoded registry level
     for that station.

Response shape:
  [ { "code": "KOSI-BIRPUR", "level": 74.82, "fetchedAt": "2026-06-09T..." }, ... ]
"""

import time
import logging
from difflib import get_close_matches
from typing import Optional

from fastapi import APIRouter, Query

try:
    from backend.routers.cwc_ffs import _fetch_ffs_stations
except ImportError:
    from routers.cwc_ffs import _fetch_ffs_stations

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["CWC Stations"])

# ── Station registry ──────────────────────────────────────────────────────────
# Maps internal code → (canonical_name, fallback_level_m)
# Fallback levels are realistic low-season baseline readings.
KNOWN_STATIONS: dict[str, tuple[str, float]] = {
    "KOSI-BIRPUR":        ("Birpur",       73.50),
    "KOSI-BASUA":         ("Basua",        68.20),
    "KOSI-KURSELA":       ("Kursela",      31.10),
    "GANDAK-DUMARIAGHAT": ("Dumariaghat",  60.80),
    "GANDAK-HAJIPUR":     ("Hajipur",      51.60),
    "GANGA-GANDHIGHAT":   ("Gandhighat",   44.90),
    "GANGA-BHAGALPUR":    ("Bhagalpur",    33.40),
    "PUNPUN-SRIPALPUR":   ("Sripalpur",    55.20),
}

# ── TTL cache ─────────────────────────────────────────────────────────────────
_cache:    dict[str, dict] = {}
_cache_ts: float           = 0.0
CACHE_TTL  = 900  # 15 min


async def _resolve_station(code: str, ffs_data: list[dict]) -> Optional[float]:
    """Try to match code → FFS level, fall back to registry."""
    entry = KNOWN_STATIONS.get(code.upper())
    if entry is None:
        return None

    canonical_name, fallback_level = entry

    # Fuzzy match against live FFS data
    names = [s["station_name"] for s in ffs_data]
    matches = get_close_matches(canonical_name, names, n=1, cutoff=0.4)
    if matches:
        matched = next((s for s in ffs_data if s["station_name"] == matches[0]), None)
        if matched and matched.get("current_level"):
            return float(matched["current_level"])

    # Substring fallback
    for s in ffs_data:
        if canonical_name.lower() in s["station_name"].lower() or \
           s["station_name"].lower() in canonical_name.lower():
            if s.get("current_level"):
                return float(s["current_level"])

    # Registry fallback
    return fallback_level


@router.get("/cwc-stations", summary="CWC gauge levels by station code")
async def get_cwc_stations(
    codes: str = Query(
        ...,
        description="Comma-separated CWC station codes, e.g. KOSI-BIRPUR,GANDAK-HAJIPUR",
    ),
):
    """
    Returns a list of current water levels for the requested CWC station codes.
    Used by the Flutter DataFetchEngine (Step 3 — CWC).
    """
    global _cache, _cache_ts
    now = time.time()

    requested = [c.strip().upper() for c in codes.split(",") if c.strip()]
    if not requested:
        return []

    # Check if all requested codes are cached and fresh
    if _cache and (now - _cache_ts) < CACHE_TTL and all(c in _cache for c in requested):
        return [_cache[c] for c in requested]

    # Fetch live FFS data (shared cache from cwc_ffs router)
    try:
        ffs_data = await _fetch_ffs_stations()
    except Exception as exc:
        logger.warning("cwc_stations: FFS fetch failed (%s), using registry fallback", exc)
        ffs_data = []

    fetched_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    result: list[dict] = []

    for code in requested:
        level = await _resolve_station(code, ffs_data)
        entry = {
            "code":      code,
            "level":     level,
            "fetchedAt": fetched_at,
            "source":    "CWC_FFS" if ffs_data and level is not None else "REGISTRY_FALLBACK",
        }
        _cache[code] = entry
        if level is not None:
            result.append(entry)

    _cache_ts = now
    return result


# ── /api/v1/stations/all  (Flutter app endpoint) ────────────────────────────
@router.get("/v1/stations/all", summary="All stations (Flutter app)")
async def all_stations_v1():
    """
    Returns all stations in the flat list format expected by
    IndiaStationsService in the Flutter app.
    """
    from backend.routers.wrd_bihar import get_wrd_bihar_data
    try:
        rows = await get_wrd_bihar_data()
    except Exception:
        rows = []

    result = []
    for r in rows:
        result.append({
            "station_id":    r.get("id") or r.get("station_id", ""),
            "city":          r.get("name") or r.get("station_name", ""),
            "state":         "Bihar",
            "district":      r.get("district", ""),
            "river_name":    r.get("river") or r.get("river_name", ""),
            "latitude":      r.get("lat") or r.get("latitude"),
            "longitude":     r.get("lon") or r.get("longitude"),
            "current_level": r.get("current_level") or r.get("water_level"),
            "danger_level":  r.get("danger_level"),
            "warning_level": r.get("warning_level"),
            "flow_rate":     r.get("discharge") or r.get("flow_rate"),
            "rainfall_24h":  r.get("rainfall_24h"),
        })
    return result
