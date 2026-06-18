"""
WRD Bihar Live River Level Router
Scrapes BeFIQR portal (irrigation.befiqr.in) — the official Central Flood
Control Cell, Water Resources Department, Govt of Bihar.

Routes:
  GET /api/wrd-bihar/stations            — all stations (live or fallback)
  GET /api/wrd-bihar/stations/{name}     — single station by name
  GET /api/wrd-bihar/summary             — danger/warning/normal counts + top alerts
  GET /api/wrd-bihar/health              — portal reachability check
  GET /api/wrd-bihar/refresh             — force immediate scrape + cache update
  GET /api/wrd-bihar/scheduler/status    — APScheduler next-run info

AUTO-REFRESH:
  APScheduler runs _scheduled_refresh() every WRD_BIHAR_POLL_INTERVAL_MIN
  minutes (default 15). It only replaces the cache when the portal returns
  fresh data, detected by comparing the newest current_level_m values.

DATA SOURCE: WRD Bihar BeFIQR only.
Live URL: https://irrigation.befiqr.in/state/table/rivers

NOTE on above_below_danger_m:
  BeFIQR scrapes a signed distance column BUT the portal sometimes returns
  unsigned magnitudes. To avoid ambiguity we ALWAYS recompute this field
  as  (current_level_m - danger_level_m)  so the sign is unambiguous:
    negative  → river is BELOW danger level (safe)
    positive  → river is ABOVE danger level (flooding)
"""

from __future__ import annotations

import datetime
import logging
import os
from typing import Any, Dict, List, Optional

import requests
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from bs4 import BeautifulSoup
from fastapi import APIRouter
from cachetools import TTLCache

log = logging.getLogger(__name__)

router = APIRouter(prefix="/api/wrd-bihar", tags=["WRD Bihar"])

# ---------------------------------------------------------------------------
# Cache — TTL slightly longer than poll interval so scheduler always owns it
# ---------------------------------------------------------------------------
_POLL_MINUTES: int = int(os.getenv("WRD_BIHAR_POLL_INTERVAL_MIN", "15"))
_CACHE: TTLCache = TTLCache(maxsize=32, ttl=(_POLL_MINUTES + 2) * 60)
_CACHE_KEY = "wrd_bihar_stations_v4"

# Scheduler singleton
_scheduler: Optional[BackgroundScheduler] = None

# ---------------------------------------------------------------------------
# BeFIQR scraper targets
# ---------------------------------------------------------------------------
_WRD_URLS = [
    "https://irrigation.befiqr.in/state/table/rivers",
    "https://irrigation.befiqr.in/state/table/wrd-manual-stations/water-level-obs",
    "http://irrigation.befiqr.in/state/table/rivers",
]

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-IN,en;q=0.9,hi;q=0.8",
    "Referer": "https://irrigation.befiqr.in/",
}

# ---------------------------------------------------------------------------
# Station registry — WRD Bihar BeFIQR gauge stations
# HFL and danger_level_m are in metres above sea level (ASL).
# ---------------------------------------------------------------------------
_STATION_REGISTRY: List[Dict[str, Any]] = [
    # ── Adhwara ──────────────────────────────────────────────────────────────
    {"station": "Ekmighat",         "river": "Adhwara",      "district": "Darbhanga / Bahadurpur",    "hfl": 59.52, "danger_level_m": 46.94, "lat": 26.095, "lon": 85.902},
    {"station": "Kamtaul",          "river": "Adhwara",      "district": "Darbhanga / Jale",           "hfl": 53.05, "danger_level_m": 50.00, "lat": 26.272, "lon": 85.959},
    {"station": "Sonbarsa",         "river": "Adhwara",      "district": "Sitamarhi / Sonbarsa",       "hfl": 83.20, "danger_level_m": 81.85, "lat": 26.799, "lon": 85.483},

    # ── Bagmati ───────────────────────────────────────────────────────────────
    {"station": "Benibad",          "river": "Bagmati",      "district": "Muzaffarpur / Gaighat",      "hfl": 50.01, "danger_level_m": 48.68, "lat": 26.005, "lon": 85.608},
    {"station": "Dheng Bridge",     "river": "Bagmati",      "district": "Sitamarhi / Suppi",          "hfl": 73.47, "danger_level_m": 71.00, "lat": 26.587, "lon": 85.480},
    {"station": "Hayaghat",         "river": "Bagmati",      "district": "Darbhanga / Hayaghat",       "hfl": 48.96, "danger_level_m": 45.72, "lat": 25.985, "lon": 85.806},
    {"station": "Runisaidpur",      "river": "Bagmati",      "district": "Muzaffarpur / Aurai",        "hfl": 58.15, "danger_level_m": 55.00, "lat": 26.549, "lon": 85.712},
    {"station": "Sitamarhi",        "river": "Bagmati",      "district": "Sitamarhi / Sadar",          "hfl": 79.20, "danger_level_m": 77.22, "lat": 26.593, "lon": 85.489},
    {"station": "Nirmali",          "river": "Bagmati",      "district": "Supaul / Nirmali",           "hfl": 46.35, "danger_level_m": 44.22, "lat": 26.313, "lon": 86.587},

    # ── Burhi Gandak ──────────────────────────────────────────────────────────
    {"station": "Khagaria",         "river": "Burhi Gandak", "district": "Khagaria / Khagaria",        "hfl": 39.22, "danger_level_m": 36.58, "lat": 25.502, "lon": 86.467},
    {"station": "Muzaffarpur",      "river": "Burhi Gandak", "district": "Muzaffarpur / Sadar",        "hfl": 53.26, "danger_level_m": 51.21, "lat": 26.121, "lon": 85.391},
    {"station": "Rosera",           "river": "Burhi Gandak", "district": "Samastipur / Rosera",        "hfl": 46.56, "danger_level_m": 42.63, "lat": 25.868, "lon": 85.992},
    {"station": "Samastipur",       "river": "Burhi Gandak", "district": "Samastipur / Samastipur",    "hfl": 49.40, "danger_level_m": 46.00, "lat": 25.877, "lon": 85.782},
    {"station": "Sikandra",         "river": "Burhi Gandak", "district": "Samastipur / Pusa",          "hfl": 51.10, "danger_level_m": 48.77, "lat": 25.989, "lon": 85.676},
    {"station": "Sikandarpur",      "river": "Burhi Gandak", "district": "Muzaffarpur / Musahari",     "hfl": 54.29, "danger_level_m": 52.53, "lat": 26.098, "lon": 85.396},

    # ── Gandak ────────────────────────────────────────────────────────────────
    {"station": "Chatia",           "river": "Gandak",       "district": "East Champaran / Areraj",    "hfl": 70.04, "danger_level_m": 69.15, "lat": 26.838, "lon": 84.879},
    {"station": "Dumariaghat",      "river": "Gandak",       "district": "Gopalganj / Sidhwalia",      "hfl": 63.70, "danger_level_m": 62.22, "lat": 26.491, "lon": 84.427},
    {"station": "Gopalpur",         "river": "Gandak",       "district": "Gopalganj / Kuchaikot",      "hfl": 66.40, "danger_level_m": 64.50, "lat": 26.620, "lon": 84.226},
    {"station": "Hajipur",          "river": "Gandak",       "district": "Vaishali / Hajipur",         "hfl": 50.93, "danger_level_m": 50.32, "lat": 25.686, "lon": 85.208},
    {"station": "Mirganj",          "river": "Gandak",       "district": "Gopalganj / Mirganj",        "hfl": 62.48, "danger_level_m": 60.98, "lat": 26.483, "lon": 84.368},
    {"station": "Rewaghat",         "river": "Gandak",       "district": "Muzaffarpur / Saraiya",      "hfl": 55.46, "danger_level_m": 54.41, "lat": 25.940, "lon": 85.383},

    # ── Ganga ─────────────────────────────────────────────────────────────────
    {"station": "Barh",             "river": "Ganga",        "district": "Patna / Barh",               "hfl": 47.65, "danger_level_m": 45.73, "lat": 25.482, "lon": 85.712},
    {"station": "Bhagalpur",        "river": "Ganga",        "district": "Bhagalpur / Nathnagar",      "hfl": 34.86, "danger_level_m": 33.68, "lat": 25.244, "lon": 86.972},
    {"station": "Buxar",            "river": "Ganga",        "district": "Buxar / Buxar",              "hfl": 62.10, "danger_level_m": 60.30, "lat": 25.564, "lon": 83.976},
    {"station": "Dighaghat",        "river": "Ganga",        "district": "Patna / Patna Rural",        "hfl": 52.52, "danger_level_m": 50.45, "lat": 25.608, "lon": 85.046},
    {"station": "Gandhighat",       "river": "Ganga",        "district": "Patna / Patna Rural",        "hfl": 50.52, "danger_level_m": 48.60, "lat": 25.594, "lon": 85.138},
    {"station": "Hathidah",         "river": "Ganga",        "district": "Patna / Mokameh",            "hfl": 43.52, "danger_level_m": 41.76, "lat": 25.390, "lon": 85.614},
    {"station": "Kahalgaon",        "river": "Ganga",        "district": "Bhagalpur / Gopalpur",       "hfl": 32.87, "danger_level_m": 31.09, "lat": 25.241, "lon": 87.248},
    {"station": "Munger",           "river": "Ganga",        "district": "Munger / Sadar Munger",      "hfl": 40.99, "danger_level_m": 39.33, "lat": 25.375, "lon": 86.473},
    {"station": "Sultanganj",       "river": "Ganga",        "district": "Bhagalpur / Sultanganj",     "hfl": 36.14, "danger_level_m": 34.50, "lat": 25.252, "lon": 86.744},

    # ── Ghaghra ───────────────────────────────────────────────────────────────
    {"station": "Darauli",          "river": "Ghaghra",      "district": "Siwan / Darauli",            "hfl": 61.82, "danger_level_m": 60.82, "lat": 26.012, "lon": 84.548},
    {"station": "Gangpur Siswan",   "river": "Ghaghra",      "district": "Siwan / Siswan",             "hfl": 58.01, "danger_level_m": 57.04, "lat": 26.219, "lon": 84.358},

    # ── Kamalabalan ───────────────────────────────────────────────────────────
    {"station": "Jhanjharpur",      "river": "Kamalabalan",  "district": "Madhubani / Jhanjharpur",    "hfl": 53.11, "danger_level_m": 50.00, "lat": 26.264, "lon": 86.280},

    # ── Kamla ─────────────────────────────────────────────────────────────────
    {"station": "Jainagar",         "river": "Kamla",        "district": "Madhubani / Jainagar",       "hfl": 71.35, "danger_level_m": 67.75, "lat": 26.599, "lon": 85.916},
    {"station": "Salempur",         "river": "Kamla",        "district": "Madhubani / Salempur",       "hfl": 56.80, "danger_level_m": 54.60, "lat": 26.398, "lon": 86.096},

    # ── Kosi ──────────────────────────────────────────────────────────────────
    {"station": "Baltara",          "river": "Kosi",         "district": "Khagaria / Beldaur",         "hfl": 36.40, "danger_level_m": 33.85, "lat": 25.458, "lon": 86.584},
    {"station": "Basua",            "river": "Kosi",         "district": "Supaul / Supaul",            "hfl": 49.24, "danger_level_m": 47.75, "lat": 26.124, "lon": 86.604},
    {"station": "Birpur",           "river": "Kosi",         "district": "Supaul / Birpur",            "hfl": 76.02, "danger_level_m": 74.70, "lat": 26.508, "lon": 86.918},
    {"station": "Koparia",          "river": "Kosi",         "district": "Supaul / Triveniganj",       "hfl": 47.85, "danger_level_m": 46.20, "lat": 26.203, "lon": 86.772},
    {"station": "Kursela",          "river": "Kosi",         "district": "Katihar / Kursela",          "hfl": 32.10, "danger_level_m": 30.00, "lat": 25.468, "lon": 87.258},
    {"station": "Naugachia",        "river": "Kosi",         "district": "Bhagalpur / Naugachia",      "hfl": 33.85, "danger_level_m": 32.10, "lat": 25.390, "lon": 87.097},

    # ── Mahananda ─────────────────────────────────────────────────────────────
    {"station": "Benipur",          "river": "Mahananda",    "district": "Madhubani / Benipur",        "hfl": 53.10, "danger_level_m": 51.21, "lat": 26.118, "lon": 86.082},
    {"station": "Bhimnagar",        "river": "Mahananda",    "district": "Supaul / Bhimnagar",         "hfl": 67.85, "danger_level_m": 66.50, "lat": 26.737, "lon": 87.077},
    {"station": "Dhengraghat",      "river": "Mahananda",    "district": "Purnia / Baisi",             "hfl": 38.20, "danger_level_m": 35.65, "lat": 26.079, "lon": 87.456},
    {"station": "Taibpur",          "river": "Mahananda",    "district": "Kishanganj / Thakurganj",    "hfl": 67.22, "danger_level_m": 66.00, "lat": 26.399, "lon": 88.016},

    # ── Punpun ────────────────────────────────────────────────────────────────
    {"station": "Sripalpur",        "river": "Punpun",       "district": "Patna / Phulwari",           "hfl": 53.91, "danger_level_m": 50.60, "lat": 25.550, "lon": 85.080},
]

_REGISTRY_MAP: Dict[str, Dict[str, Any]] = {
    " ".join(s["station"].lower().split()): s for s in _STATION_REGISTRY
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _normalize(value: str) -> str:
    return " ".join((value or "").strip().lower().split())


def _safe_float(value: Any) -> Optional[float]:
    """Parse float from scraped cell. Returns None for missing/invalid."""
    try:
        v = str(value).strip().replace(",", "")
        if v in ("", "--", "N/A", "NA", "-", ".", "nil", "NIL"):
            return None
        return round(float(v), 3)
    except (ValueError, TypeError):
        return None


def _enrich(station_name: str) -> Dict[str, Any]:
    key = _normalize(station_name)
    if key in _REGISTRY_MAP:
        return _REGISTRY_MAP[key]
    for rk, rv in _REGISTRY_MAP.items():
        if rk in key or key in rk:
            return rv
    # No match — warn so new BeFIQR stations surface immediately in logs
    log.warning(
        "[WRD Bihar] Unmatched station '%s' — not in _STATION_REGISTRY. "
        "Add it with correct lat/lon/hfl/danger_level_m to get accurate data.",
        station_name,
    )
    return {"station": station_name, "river": "Unknown", "district": "Bihar",
            "hfl": None, "danger_level_m": None, "lat": 25.8, "lon": 85.4}


def _status_label(
    current: Optional[float],
    danger: Optional[float],
    hfl: Optional[float],
    above_dl: Optional[float],
) -> str:
    """
    Status derived from signed above_dl (current - danger level):
      CRITICAL  — above danger AND near/above HFL
      DANGER    — at or above danger level
      WARNING   — within 3 m below danger level
      NORMAL    — more than 3 m below danger level
      UNKNOWN   — no current reading
    """
    if current is None or above_dl is None:
        return "UNKNOWN"
    if above_dl >= 0:
        return "CRITICAL" if (hfl and current >= hfl * 0.97) else "DANGER"
    if above_dl >= -3.0:
        return "WARNING"
    if current > 0:
        return "NORMAL"
    return "UNKNOWN"


# ---------------------------------------------------------------------------
# BeFIQR table parser
# Column order (0-indexed): 0=SL 1=River 2=Site 3=HFL 4=DL 5=Yest
#                           6=Current 7=Diff24h 8=AboveBelowDL 9=Trend 10=District
# ---------------------------------------------------------------------------
_BEFIQR_COL = {"river": 1, "site": 2, "hfl": 3, "dl": 4, "yest": 5,
               "current": 6, "diff": 7, "above": 8, "trend": 9, "dist": 10}


def _parse_befiqr_table(soup: BeautifulSoup) -> List[Dict[str, Any]]:
    stations: List[Dict[str, Any]] = []
    now = _now_iso()

    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        if len(rows) < 3:
            continue
        all_text = table.get_text(" ", strip=True).lower()
        if not any(k in all_text for k in ["river", "site", "hfl", "danger"]):
            continue

        header_cells: List[str] = []
        for hr in rows[:3]:
            cells = [c.get_text(" ", strip=True).lower() for c in hr.find_all(["th", "td"])]
            if len(cells) > len(header_cells):
                header_cells = cells

        def col_idx(keywords: List[str], default: int) -> int:
            for kw in keywords:
                for i, h in enumerate(header_cells):
                    if kw in h:
                        return i
            return default

        i_river   = col_idx(["river", "nadi"],                       _BEFIQR_COL["river"])
        i_site    = col_idx(["site", "station", "gauge"],            _BEFIQR_COL["site"])
        i_hfl     = col_idx(["hfl"],                                 _BEFIQR_COL["hfl"])
        i_dl      = col_idx(["dl", "danger level", "danger"],       _BEFIQR_COL["dl"])
        i_yest    = col_idx(["yesterday", "previous", "yest"],       _BEFIQR_COL["yest"])
        i_current = col_idx(["current observed", "current wl",
                             "current level", "observed wl"],        _BEFIQR_COL["current"])
        i_diff    = col_idx(["diff", "24", "change"],                _BEFIQR_COL["diff"])
        i_trend   = col_idx(["trend", "today"],                      _BEFIQR_COL["trend"])
        i_dist    = col_idx(["district", "block"],                   _BEFIQR_COL["dist"])

        for row in rows[1:]:
            cells = [td.get_text(" ", strip=True) for td in row.find_all("td")]
            if len(cells) < 5:
                continue

            def c(idx: int) -> str:
                return cells[idx].strip() if 0 <= idx < len(cells) else ""

            site = c(i_site)
            if not site or site.lower() in ("site", "station", "sl", "#", "(3)", "",
                                            "river", "hfl (mts)", "dl (mts)"):
                continue

            river    = c(i_river)
            hfl      = _safe_float(c(i_hfl))
            dl       = _safe_float(c(i_dl))
            yest     = _safe_float(c(i_yest))
            current  = _safe_float(c(i_current))
            diff_24h = _safe_float(c(i_diff))
            trend    = c(i_trend) or "—"
            district = c(i_dist)

            meta = _enrich(site)
            if not river:    river    = meta.get("river", "Unknown")
            if not district: district = meta.get("district", "Bihar")
            if hfl is None:  hfl      = meta.get("hfl")
            if dl is None:   dl       = meta.get("danger_level_m")

            # ----------------------------------------------------------------
            # above_below_danger_m: ALWAYS computed as (current - danger_level)
            # negative = river BELOW danger level (safe)
            # positive = river ABOVE danger level (flooding!)
            # ----------------------------------------------------------------
            above_dl: Optional[float] = None
            if current is not None and dl is not None and dl > 0:
                above_dl = round(current - dl, 3)

            stations.append({
                "station":              site,
                "river":                river,
                "district":             district,
                "lat":                  meta.get("lat", 25.8),
                "lon":                  meta.get("lon", 85.4),
                "hfl_m":                hfl,
                "danger_level_m":       dl,
                "yesterday_level_m":    yest,
                "current_level_m":      current,
                "change_24h_m":         diff_24h,
                "above_below_danger_m": above_dl,
                "trend":                trend,
                "status":               _status_label(current, dl, hfl, above_dl),
                "source":               "WRD_BIHAR_BEFIQR",
                "last_update":          now,
            })

        if stations:
            break

    return stations


# ---------------------------------------------------------------------------
# Live fetch
# ---------------------------------------------------------------------------

def _fetch_befiqr_live() -> Dict[str, Any]:
    errors: List[str] = []
    timeout = (
        max(3.0, float(os.getenv("WRD_BIHAR_CONNECT_TIMEOUT", "6"))),
        max(8.0, float(os.getenv("WRD_BIHAR_READ_TIMEOUT", "20"))),
    )
    for url in _WRD_URLS:
        try:
            resp = requests.get(url, headers=_HEADERS, timeout=timeout)
            resp.raise_for_status()
            soup = BeautifulSoup(resp.text, "html.parser")
            stations = _parse_befiqr_table(soup)
            if stations:
                return {
                    "status": "LIVE",
                    "data_source": "WRD_BIHAR_BEFIQR",
                    "source_url": url,
                    "station_count": len(stations),
                    "timestamp": _now_iso(),
                    "stations": stations,
                }
            errors.append(f"{url}: page loaded (HTTP {resp.status_code}) but no table rows extracted")
        except requests.Timeout:
            errors.append(f"{url}: timeout")
        except requests.RequestException as exc:
            errors.append(f"{url}: {exc.__class__.__name__} — {str(exc)[:140]}")
    raise RuntimeError(" | ".join(errors))


# ---------------------------------------------------------------------------
# Fallback
# ---------------------------------------------------------------------------

def _tactical_fallback(scrape_error: str = "") -> Dict[str, Any]:
    now = _now_iso()
    stations = [{
        "station":              s["station"],
        "river":                s["river"],
        "district":             s["district"],
        "lat":                  s["lat"],
        "lon":                  s["lon"],
        "hfl_m":                s["hfl"],
        "danger_level_m":       s["danger_level_m"],
        "yesterday_level_m":    None,
        "current_level_m":      None,
        "change_24h_m":         None,
        "above_below_danger_m": None,
        "trend":                "—",
        "status":               "UNKNOWN",
        "source":               "WRD_BIHAR_FALLBACK",
        "last_update":          now,
    } for s in _STATION_REGISTRY]
    result = {
        "status": "FALLBACK",
        "data_source": "WRD_BIHAR_FALLBACK",
        "source_url": None,
        "station_count": len(stations),
        "timestamp": now,
        "stations": stations,
    }
    if scrape_error:
        result["_scrape_error"] = scrape_error[:500]
    return result


# ---------------------------------------------------------------------------
# Shared getter (used by all route handlers)
# ---------------------------------------------------------------------------

async def _get_stations(force_refresh: bool = False) -> Dict[str, Any]:
    if not force_refresh and _CACHE_KEY in _CACHE:
        cached = dict(_CACHE[_CACHE_KEY])
        cached["_cache_hit"] = True
        return cached
    try:
        result = _fetch_befiqr_live()
        _CACHE[_CACHE_KEY] = result
        result = dict(result)
        result["_cache_hit"] = False
        return result
    except RuntimeError as exc:
        fallback = _tactical_fallback(str(exc))
        fallback["_cache_hit"] = False
        return fallback


# ---------------------------------------------------------------------------
# APScheduler — background auto-refresh
# ---------------------------------------------------------------------------

def _scheduled_refresh() -> None:
    log.info("[WRD Bihar] Scheduled refresh started")
    try:
        fresh = _fetch_befiqr_live()
        new_levels = {s["station"]: s["current_level_m"] for s in fresh["stations"]}
        old_result = _CACHE.get(_CACHE_KEY)
        if old_result:
            old_levels = {s["station"]: s["current_level_m"] for s in old_result["stations"]}
            if new_levels == old_levels:
                log.info("[WRD Bihar] Portal not yet updated — cache kept (levels unchanged)")
                return
            log.info("[WRD Bihar] Portal data changed — updating cache")
        else:
            log.info("[WRD Bihar] Cache was empty — populating")
        _CACHE[_CACHE_KEY] = fresh
        log.info(f"[WRD Bihar] Cache refreshed: {fresh['station_count']} stations at {fresh['timestamp']}")
    except RuntimeError as exc:
        log.warning(f"[WRD Bihar] Scheduled refresh failed: {exc}")


def start_scheduler() -> None:
    global _scheduler
    if _scheduler and _scheduler.running:
        return
    _scheduler = BackgroundScheduler(timezone="Asia/Kolkata", daemon=True)
    _scheduler.add_job(
        _scheduled_refresh,
        trigger=IntervalTrigger(minutes=_POLL_MINUTES),
        id="wrd_bihar_refresh",
        name=f"WRD Bihar BeFIQR scrape every {_POLL_MINUTES} min",
        replace_existing=True,
        max_instances=1,
        misfire_grace_time=120,
    )
    _scheduler.start()
    log.info(f"[WRD Bihar] Scheduler started — polling every {_POLL_MINUTES} min (IST)")


def stop_scheduler() -> None:
    global _scheduler
    if _scheduler and _scheduler.running:
        _scheduler.shutdown(wait=False)
        log.info("[WRD Bihar] Scheduler stopped")


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@router.get("/stations")
async def get_wrd_bihar_stations(
    force_refresh: bool = False,
    river: Optional[str] = None,
    district: Optional[str] = None,
) -> Dict[str, Any]:
    """All WRD Bihar stations. Filters: ?river=Ganga ?district=Patna ?force_refresh=true"""
    result = await _get_stations(force_refresh=force_refresh)
    stations = result.get("stations", [])
    if river:
        rk = _normalize(river)
        stations = [s for s in stations if rk in _normalize(s.get("river", ""))]
    if district:
        dk = _normalize(district)
        stations = [s for s in stations if dk in _normalize(s.get("district", ""))]
    return {**result, "station_count": len(stations), "stations": stations}


@router.get("/stations/{station_name}")
async def get_wrd_bihar_station(station_name: str, force_refresh: bool = False) -> Dict[str, Any]:
    """Single station by name (case-insensitive partial match)."""
    all_data = await _get_stations(force_refresh=force_refresh)
    key = _normalize(station_name)
    matches = [
        s for s in all_data.get("stations", [])
        if key in _normalize(s.get("station", "")) or _normalize(s.get("station", "")) in key
    ]
    if not matches:
        return {"status": "NOT_FOUND", "data_source": all_data["data_source"],
                "timestamp": all_data["timestamp"], "query": station_name, "station": None}
    return {"status": all_data["status"], "data_source": all_data["data_source"],
            "timestamp": all_data["timestamp"], "station": matches[0]}


@router.get("/summary")
async def get_wrd_bihar_summary(force_refresh: bool = False) -> Dict[str, Any]:
    """Bihar flood summary — alert level, counts, top 5 alerts."""
    all_data = await _get_stations(force_refresh=force_refresh)
    stations = all_data.get("stations", [])

    counts: Dict[str, int] = {"CRITICAL": 0, "DANGER": 0, "WARNING": 0, "NORMAL": 0, "UNKNOWN": 0}
    alert_stations: List[Dict[str, Any]] = []

    for s in stations:
        status = s.get("status", "UNKNOWN")
        counts[status] = counts.get(status, 0) + 1
        current = s.get("current_level_m")
        dl = s.get("danger_level_m")
        if current is not None and dl and dl > 0:
            alert_stations.append({**s, "_pct": round(current / dl * 100, 1)})

    alert_stations.sort(key=lambda x: x["_pct"], reverse=True)

    if counts["CRITICAL"] > 0:  state_alert = "RED"
    elif counts["DANGER"] > 0:  state_alert = "ORANGE"
    elif counts["WARNING"] > 0: state_alert = "YELLOW"
    elif counts["NORMAL"] > 0:  state_alert = "GREEN"
    else:                        state_alert = "GREY"

    return {
        "status":            all_data["status"],
        "data_source":       all_data["data_source"],
        "timestamp":         all_data["timestamp"],
        "state":             "Bihar",
        "total_stations":    len(stations),
        "state_alert_level": state_alert,
        "station_counts":    counts,
        "top_alerts": [
            {"station": s["station"], "river": s["river"], "district": s["district"],
             "current_level_m": s["current_level_m"], "danger_level_m": s["danger_level_m"],
             "above_below_danger_m": s.get("above_below_danger_m"),
             "status": s["status"]}
            for s in alert_stations[:5]
        ],
    }


@router.get("/refresh")
async def force_refresh_wrd_bihar() -> Dict[str, Any]:
    """Force immediate scrape of BeFIQR and update the cache."""
    log.info("[WRD Bihar] Manual /refresh triggered")
    result = await _get_stations(force_refresh=True)
    return {
        "refreshed":     True,
        "status":        result["status"],
        "data_source":   result["data_source"],
        "timestamp":     result["timestamp"],
        "station_count": result["station_count"],
        "_cache_hit":    result.get("_cache_hit", False),
    }


@router.get("/scheduler/status")
async def scheduler_status() -> Dict[str, Any]:
    """APScheduler job info — next run time, poll interval, running state."""
    global _scheduler
    if not _scheduler or not _scheduler.running:
        return {"running": False, "message": "Scheduler not started."}
    job = _scheduler.get_job("wrd_bihar_refresh")
    next_run = job.next_run_time.isoformat() if (job and job.next_run_time) else None
    cached = _CACHE.get(_CACHE_KEY)
    return {
        "running":            True,
        "poll_interval_min":  _POLL_MINUTES,
        "next_run_ist":       next_run,
        "last_cached_at_utc": cached["timestamp"] if cached else None,
        "cache_has_data":     cached is not None,
        "job_id":             "wrd_bihar_refresh",
    }


@router.get("/health")
async def wrd_bihar_health() -> Dict[str, Any]:
    """Check if BeFIQR portal is reachable."""
    primary_url = _WRD_URLS[0]
    try:
        resp = requests.get(primary_url, headers=_HEADERS, timeout=(4, 10))
        return {"reachable": resp.ok, "status_code": resp.status_code,
                "url": primary_url, "timestamp": _now_iso()}
    except requests.RequestException as exc:
        return {"reachable": False, "error": str(exc)[:250],
                "url": primary_url, "timestamp": _now_iso()}


# ── /api/v1/stations/all  (Flutter IndiaStationsService endpoint) ────────────
@router.get("/stations/all", summary="All Bihar stations (Flutter app format)")
async def stations_all_v1():
    """
    Flat list of all Bihar stations in the shape expected by
    IndiaStationsService (lib/services/india_stations_service.dart).
    """
    data = await _get_stations()          # existing cached fetch
    stations = data.get("stations", [])
    result = []
    for s in stations:
        result.append({
            "station_id":    s.get("station", ""),
            "city":          s.get("station", ""),
            "state":         "Bihar",
            "district":      s.get("district", ""),
            "river_name":    s.get("river", ""),
            "latitude":      s.get("lat"),
            "longitude":     s.get("lon"),
            "current_level": s.get("current_level_m"),
            "danger_level":  s.get("danger_level_m"),
            "warning_level": s.get("warning_level_m"),
            "flow_rate":     s.get("discharge"),
            "rainfall_24h":  s.get("rainfall_24h"),
        })
    return result
