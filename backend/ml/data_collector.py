# backend/ml/data_collector.py
# =============================================================================
# OpsFlood  v1.0  —  Live Data Collector
# =============================================================================
#
# Mirrors the exact same API calls as DataFetchEngine (data_fetch_engine.dart)
# and pipes every reading into per-station CSV files that model_train.py reads.
#
# ENDPOINTS USED (same as Flutter app)
#   GET /api/live-levels?state=Bihar
#   GET /api/glofas?lats=...&lons=...&cities=...
#   GET /api/rainfall?lats=...&lons=...&cities=...
#
# OUTPUT
#   data/raw/<StationName>.csv
#   Columns: timestamp, level_m, rain_1h, rain_3d, rain_7d,
#            upstream_level, forecast_mm, soil_moisture,
#            discharge_m3s, day_sin, day_cos, hour_sin
#
# USAGE
#   python -m backend.ml.data_collector --collect          # poll every 15 min
#   python -m backend.ml.data_collector --collect --interval 5   # every 5 min
#   python -m backend.ml.data_collector --status           # show CSV row counts
#   python -m backend.ml.data_collector --train            # collect + auto-train
#   python -m backend.ml.data_collector --backfill 30      # fill 30 days synthetic
# =============================================================================
from __future__ import annotations

import argparse
import math
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional

import numpy as np
import pandas as pd
import requests

# =============================================================================
# CONFIG
# =============================================================================
BACKEND_URL   = os.getenv(
    'BACKEND_URL',
    'https://android-flood-app-production.up.railway.app'
)
DEFAULT_POLL  = 15        # minutes between polls
MIN_ROWS_TRAIN = 500      # minimum rows before auto-training a station
TIMEOUT       = 30        # HTTP timeout seconds

ROOT_DIR  = Path(__file__).parents[2]
RAW_DIR   = ROOT_DIR / 'data' / 'raw'
RAW_DIR.mkdir(parents=True, exist_ok=True)

# Features expected by model_train.py
CSV_COLS = [
    'timestamp', 'level_m', 'rain_1h', 'rain_3d', 'rain_7d',
    'upstream_level', 'forecast_mm', 'soil_moisture',
    'discharge_m3s', 'day_sin', 'day_cos', 'hour_sin',
]

# =============================================================================
# API HELPERS  (mirrors backend_api_service.dart)
# =============================================================================
def fetch_live_levels(state: str = 'Bihar') -> List[Dict]:
    url = f'{BACKEND_URL}/api/live-levels?state={state}'
    r   = requests.get(url, timeout=TIMEOUT)
    r.raise_for_status()
    body = r.json()
    if isinstance(body, list):      return body
    if isinstance(body, dict):
        if 'stations' in body:      return body['stations']
        if 'data'     in body:      return body['data']
    return []


def fetch_glofas(lats: List[float], lons: List[float],
                 cities: List[str]) -> List[Dict]:
    url = (
        f'{BACKEND_URL}/api/glofas'
        f'?lats={_csv(lats)}&lons={_csv(lons)}&cities={_csv(cities)}'
    )
    r = requests.get(url, timeout=TIMEOUT)
    r.raise_for_status()
    body = r.json()
    return body if isinstance(body, list) else []


def fetch_rainfall(lats: List[float], lons: List[float],
                   cities: List[str]) -> List[Dict]:
    url = (
        f'{BACKEND_URL}/api/rainfall'
        f'?lats={_csv(lats)}&lons={_csv(lons)}&cities={_csv(cities)}'
    )
    r = requests.get(url, timeout=TIMEOUT)
    r.raise_for_status()
    body = r.json()
    return body if isinstance(body, list) else []


def _csv(items) -> str:
    return ','.join(str(x) for x in items)

# =============================================================================
# CYCLOMATIC FEATURE DERIVATION
# =============================================================================
def _time_features(ts: datetime):
    doy      = ts.timetuple().tm_yday
    day_sin  = math.sin(2 * math.pi * doy / 365)
    day_cos  = math.cos(2 * math.pi * doy / 365)
    hour_sin = math.sin(2 * math.pi * ts.hour / 24)
    return day_sin, day_cos, hour_sin


def _rain_windows(station_name: str, rain_1h: float) -> tuple:
    """
    Compute rain_3d and rain_7d from the existing CSV if available,
    otherwise estimate from rain_1h.
    """
    csv_path = RAW_DIR / f'{station_name}.csv'
    if csv_path.exists():
        try:
            df    = pd.read_csv(csv_path, usecols=['rain_1h'])
            tail3 = float(df['rain_1h'].tail(72).sum())  + rain_1h
            tail7 = float(df['rain_1h'].tail(168).sum()) + rain_1h
            return tail3, tail7
        except Exception:
            pass
    # fallback: rough estimate
    return rain_1h * 24 * 3, rain_1h * 24 * 7


def _upstream_level(station_name: str, current_level: float,
                    all_stations: Dict[str, Dict]) -> float:
    """
    Find the upstream station by name heuristics and return its level.
    Falls back to current_level + small offset.
    """
    sn = station_name.lower()
    for name, info in all_stations.items():
        n = name.lower()
        if n != sn and info.get('river') == all_stations.get(station_name, {}).get('river'):
            lvl = info.get('level', 0.0)
            if lvl > current_level * 0.5:   # plausible upstream reading
                return lvl
    return current_level + np.random.uniform(-0.5, 1.5)


def _soil_moisture(rain_3d: float) -> float:
    """Simple proxy: 3-day rain normalised to 0-1 (saturates at 150mm)."""
    return min(rain_3d / 150.0, 1.0)

# =============================================================================
# COLLECT ONE SNAPSHOT
# =============================================================================
def collect_snapshot(verbose: bool = True) -> int:
    """
    Fetch one round of data from all 3 APIs and append rows to CSVs.
    Returns number of stations updated.
    """
    now = datetime.utcnow().replace(second=0, microsecond=0)
    ts  = now.isoformat()

    # ── 1. live-levels
    if verbose: print(f'[{now:%H:%M:%S}] Fetching live-levels ...')
    try:
        levels = fetch_live_levels('Bihar')
    except Exception as e:
        print(f'  [ERROR] live-levels: {e}')
        return 0

    if not levels:
        print('  [WARN] No stations returned from live-levels')
        return 0
    if verbose: print(f'  ✓ {len(levels)} stations')

    # Build lookup dict for upstream heuristic
    station_lookup: Dict[str, Dict] = {}
    for st in levels:
        name = (
            st.get('stationName') or st.get('station') or
            st.get('name') or st.get('n') or ''
        )
        lvl  = float(
            st.get('currentLevel') or st.get('level') or
            st.get('cl') or 0.0
        )
        river = (
            st.get('river') or st.get('r') or ''
        )
        station_lookup[name] = {'level': lvl, 'river': river, 'raw': st}

    # ── 2. GloFAS discharge
    lats   = [float((st.get('raw') or st).get('lat',  0) or
                    (st.get('raw') or st).get('la', 0))
              for st in station_lookup.values()]
    lons   = [float((st.get('raw') or st).get('lon',  0) or
                    (st.get('raw') or st).get('lo', 0))
              for st in station_lookup.values()]
    cities = [n.lower().replace(' ', '_') for n in station_lookup.keys()]

    glofas_data:   Dict[str, float] = {}
    rainfall_data: Dict[str, float] = {}
    forecast_data: Dict[str, float] = {}

    try:
        gf_rows = fetch_glofas(lats, lons, cities)
        for i, row in enumerate(gf_rows):
            if i < len(cities):
                dis = row.get('discharge') or row.get('dis') or 0.0
                glofas_data[cities[i]] = float(dis)
        if verbose: print(f'  ✓ GloFAS: {len(glofas_data)} readings')
    except Exception as e:
        if verbose: print(f'  [WARN] GloFAS: {e}')

    try:
        rf_rows = fetch_rainfall(lats, lons, cities)
        for i, row in enumerate(rf_rows):
            if i < len(cities):
                rain = row.get('rainfall24h') or row.get('rain') or 0.0
                fcast = row.get('forecast24h') or row.get('forecast_mm') or rain
                rainfall_data[cities[i]] = float(rain) / 24.0  # 24h -> 1h rate
                forecast_data[cities[i]] = float(fcast)
        if verbose: print(f'  ✓ Rainfall: {len(rainfall_data)} readings')
    except Exception as e:
        if verbose: print(f'  [WARN] Rainfall: {e}')

    # ── 3. Build rows and append
    updated = 0
    for name, info in station_lookup.items():
        if not name:
            continue

        raw          = info['raw']
        level_m      = info['level']
        city_key     = name.lower().replace(' ', '_')
        rain_1h      = rainfall_data.get(city_key, 0.0)
        rain_3d, rain_7d = _rain_windows(name, rain_1h)
        discharge    = glofas_data.get(city_key, 0.0)
        forecast_mm  = forecast_data.get(city_key, rain_1h * 24)
        soil_moist   = _soil_moisture(rain_3d)
        up_level     = _upstream_level(name, level_m, station_lookup)
        day_sin, day_cos, hour_sin = _time_features(now)

        # Also grab forecastLevel24h if live-levels returned it
        f24 = float(
            raw.get('forecastLevel24h') or raw.get('f1') or
            raw.get('forecast24h') or forecast_mm
        )

        row = {
            'timestamp':      ts,
            'level_m':        round(level_m,   4),
            'rain_1h':        round(rain_1h,   4),
            'rain_3d':        round(rain_3d,   4),
            'rain_7d':        round(rain_7d,   4),
            'upstream_level': round(up_level,  4),
            'forecast_mm':    round(forecast_mm, 4),
            'soil_moisture':  round(soil_moist, 4),
            'discharge_m3s':  round(discharge, 2),
            'day_sin':        round(day_sin,   6),
            'day_cos':        round(day_cos,   6),
            'hour_sin':       round(hour_sin,  6),
        }

        _append_row(name, row)
        updated += 1

    if verbose:
        print(f'  ✓ Appended to {updated} station CSVs')
    return updated

# =============================================================================
# CSV I/O
# =============================================================================
def _append_row(station: str, row: dict):
    # Sanitise filename
    safe = station.replace('/', '_').replace('\\', '_').strip()
    path = RAW_DIR / f'{safe}.csv'

    if path.exists():
        # Dedup: skip if last timestamp is the same
        try:
            tail = pd.read_csv(path, usecols=['timestamp']).tail(1)
            if not tail.empty and tail.iloc[-1]['timestamp'] == row['timestamp']:
                return
        except Exception:
            pass
        # Append without header
        pd.DataFrame([row])[CSV_COLS].to_csv(
            path, mode='a', header=False, index=False
        )
    else:
        pd.DataFrame([row])[CSV_COLS].to_csv(
            path, mode='w', header=True, index=False
        )

# =============================================================================
# STATUS
# =============================================================================
def show_status():
    csvs = sorted(RAW_DIR.glob('*.csv'))
    if not csvs:
        print('No CSVs yet. Run: python -m backend.ml.data_collector --collect')
        return
    print(f'\n{"Station":<35} {"Rows":>8}  {"From":<20}  {"To":<20}')
    print('-' * 90)
    total_rows = 0
    for p in csvs:
        try:
            df   = pd.read_csv(p, usecols=['timestamp'])
            n    = len(df)
            frm  = df['timestamp'].iloc[0]  if n > 0 else ''
            to   = df['timestamp'].iloc[-1] if n > 0 else ''
            ready = '✓ ready' if n >= MIN_ROWS_TRAIN else f'need {MIN_ROWS_TRAIN - n} more'
            print(f'{p.stem:<35} {n:>8}  {str(frm)[:19]:<20}  {str(to)[:19]:<20}  {ready}')
            total_rows += n
        except Exception as e:
            print(f'{p.stem:<35}  [ERROR] {e}')
    print('-' * 90)
    print(f'Total: {len(csvs)} stations, {total_rows:,} rows')
    print(f'Min rows for training: {MIN_ROWS_TRAIN}')
    ready = sum(1 for p in csvs if _row_count(p) >= MIN_ROWS_TRAIN)
    print(f'Ready to train: {ready}/{len(csvs)} stations\n')


def _row_count(p: Path) -> int:
    try:
        return sum(1 for _ in open(p)) - 1  # fast line count minus header
    except Exception:
        return 0

# =============================================================================
# BACKFILL
# =============================================================================
def backfill(days: int):
    """
    For stations that already have CSVs, generate synthetic historical rows
    going N days back so model_train.py has enough rows immediately.
    For stations with no CSVs yet, creates synthetic data for all known stations.
    """
    print(f'Backfilling {days} days of synthetic data ...')
    csvs = list(RAW_DIR.glob('*.csv'))

    # Also include known stations with no CSV yet
    known_stations = [
        'Triveni', 'Gandhighat', 'Hathidah', 'Buxar', 'Digha', 'Kursela',
        'Bhagalpur', 'Kahalgaon', 'Munger', 'Sultanganj', 'Barh', 'Mokama',
        'Simaria', 'Barauni', 'Khagaria', 'Rosera', 'Hayaghat', 'Runni_Saidpur',
        'Dheng', 'Lalbegia', 'Muzaffarpur', 'Sonpur', 'Hajipur', 'Doriganj',
        'Gopalganj', 'Siwan', 'Chhapra', 'Revelganj', 'Arrah', 'Koilwar',
        'Patna', 'Fatuha', 'Begusarai', 'Sahibganj',
        'Birpur', 'Basua', 'Dumariaghat', 'Sripalpur', 'Jainagar',
        'Dhengraghat',
    ]
    existing = {p.stem for p in csvs}
    targets  = list(existing) + [s for s in known_stations if s not in existing]

    for station in targets:
        _backfill_station(station, days)
    print(f'Done. Backfilled {len(targets)} stations.')
    show_status()


def _backfill_station(station: str, days: int):
    path  = RAW_DIR / f'{station}.csv'
    n     = days * 24  # hourly rows
    now   = datetime.utcnow().replace(minute=0, second=0, microsecond=0)
    times = [now - timedelta(hours=i) for i in range(n, 0, -1)]

    np.random.seed(abs(hash(station)) % (2**31))
    doy   = np.array([t.timetuple().tm_yday for t in times])
    base  = 45 + 20 * np.sin(2 * np.pi * doy / 365 - 1.2)
    noise = np.cumsum(np.random.randn(n) * 0.05)
    level = np.clip(base + noise + np.random.randn(n) * 0.8, 20, 100)
    rain  = np.clip(
        8 * np.sin(2 * np.pi * doy / 365 - 1.0)**6 +
        np.random.exponential(0.5, n), 0, 10
    )  # per-hour mm

    rain_s = pd.Series(rain)
    r3d    = rain_s.rolling(72,  min_periods=1).sum().values
    r7d    = rain_s.rolling(168, min_periods=1).sum().values

    day_sin  = np.sin(2 * np.pi * doy / 365)
    day_cos  = np.cos(2 * np.pi * doy / 365)
    hour_arr = np.array([t.hour for t in times])
    hour_sin = np.sin(2 * np.pi * hour_arr / 24)

    df = pd.DataFrame({
        'timestamp':      [t.isoformat() for t in times],
        'level_m':        np.round(level, 4),
        'rain_1h':        np.round(rain,  4),
        'rain_3d':        np.round(r3d,   4),
        'rain_7d':        np.round(r7d,   4),
        'upstream_level': np.round(level + np.random.randn(n)*1.5, 4),
        'forecast_mm':    np.round(np.clip(rain*24 + np.random.randn(n)*2, 0, 200), 4),
        'soil_moisture':  np.round(np.clip(r3d / 150.0, 0, 1), 4),
        'discharge_m3s':  np.round(np.clip(500 + level*30 + np.random.randn(n)*50, 100, 15000), 2),
        'day_sin':        np.round(day_sin,  6),
        'day_cos':        np.round(day_cos,  6),
        'hour_sin':       np.round(hour_sin, 6),
    })

    if path.exists():
        existing_df = pd.read_csv(path)
        existing_ts = set(existing_df['timestamp'].values)
        df = df[~df['timestamp'].isin(existing_ts)]
        if df.empty:
            return
        combined = pd.concat([df, existing_df], ignore_index=True)
        combined = combined.drop_duplicates('timestamp').sort_values('timestamp')
        combined[CSV_COLS].to_csv(path, index=False)
    else:
        df[CSV_COLS].to_csv(path, index=False)

    print(f'  {station:<35} +{len(df)} rows  →  {path.name}')

# =============================================================================
# COLLECT LOOP
# =============================================================================
def collect_loop(interval_min: int = DEFAULT_POLL, auto_train: bool = False):
    print(f'OpsFlood Data Collector — polling every {interval_min} min')
    print(f'Backend: {BACKEND_URL}')
    print(f'Output : {RAW_DIR}')
    print('Press Ctrl+C to stop.\n')

    while True:
        try:
            n = collect_snapshot(verbose=True)
            if auto_train:
                _auto_train_ready()
        except KeyboardInterrupt:
            print('\nStopped.')
            break
        except Exception as e:
            print(f'[ERROR] Snapshot failed: {e}')

        print(f'  Next poll in {interval_min} min ...')
        time.sleep(interval_min * 60)


def _auto_train_ready():
    """Trigger model_train.py for any station that just crossed MIN_ROWS_TRAIN."""
    for p in RAW_DIR.glob('*.csv'):
        if _row_count(p) >= MIN_ROWS_TRAIN:
            station = p.stem
            model_p = Path(__file__).parent / 'saved_models' / f'{station}_bilstm.pt'
            if not model_p.exists():
                print(f'  ↻ Auto-training {station} ...')
                subprocess.Popen([
                    sys.executable, '-m', 'backend.ml.model_train',
                    '--station', station,
                ])

# =============================================================================
# MAIN
# =============================================================================
def main():
    ap = argparse.ArgumentParser(description='OpsFlood Live Data Collector')
    ap.add_argument('--collect',   action='store_true',
                    help='Start polling loop (default interval 15 min)')
    ap.add_argument('--interval',  type=int, default=DEFAULT_POLL,
                    help='Poll interval in minutes (default 15)')
    ap.add_argument('--status',    action='store_true',
                    help='Show CSV row counts for all stations')
    ap.add_argument('--backfill',  type=int, metavar='DAYS', default=0,
                    help='Backfill N days of synthetic data and exit')
    ap.add_argument('--train',     action='store_true',
                    help='Collect one snapshot then trigger model_train.py --station all')
    ap.add_argument('--state',     default='Bihar',
                    help='State to collect (default: Bihar)')
    args = ap.parse_args()

    if args.status:
        show_status()
        return

    if args.backfill > 0:
        backfill(args.backfill)
        return

    if args.train:
        print('Collecting one snapshot ...')
        collect_snapshot(verbose=True)
        print('\nLaunching model_train.py --station all --plot ...')
        subprocess.run([
            sys.executable, '-m', 'backend.ml.model_train',
            '--station', 'all', '--plot',
        ])
        return

    if args.collect:
        collect_loop(interval_min=args.interval)
        return

    # Default: collect one snapshot and show status
    print('Collecting one snapshot ...')
    collect_snapshot(verbose=True)
    show_status()


if __name__ == '__main__':
    main()
