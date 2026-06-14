# backend/ml/historical_downloader.py
# =============================================================================
# OpsFlood  v1.0  —  5-Year Historical Data Downloader
# =============================================================================
#
# Uses the same FREE APIs already used by cwc_scraper.py:
#
#   1. Open-Meteo GloFAS Flood API  (river discharge, daily, up to 5 years)
#      https://flood-api.open-meteo.com/v1/flood
#      - No API key, no IP block, works from anywhere
#      - daily river_discharge (m³/s) with past_days up to 1826 (5 years)
#
#   2. Open-Meteo Archive API  (hourly rainfall, 2000-present)
#      https://archive-api.open-meteo.com/v1/archive
#      - No API key, completely free
#      - hourly precipitation (mm), soil_moisture, etc.
#
# OUTPUT
#   data/raw/<StationName>.csv  with columns:
#   timestamp, level_m, rain_1h, rain_3d, rain_7d,
#   upstream_level, forecast_mm, soil_moisture,
#   discharge_m3s, day_sin, day_cos, hour_sin
#
# USAGE
#   python -m backend.ml.historical_downloader --download           # all stations
#   python -m backend.ml.historical_downloader --station Patna      # one station
#   python -m backend.ml.historical_downloader --years 3            # last 3 years
#   python -m backend.ml.historical_downloader --status             # show coverage
#   python -m backend.ml.historical_downloader --download --merge   # merge with existing
#
# INSTALL
#   pip install requests pandas numpy tqdm
# =============================================================================
from __future__ import annotations

import argparse
import math
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
import requests
from tqdm import tqdm

# =============================================================================
# PATHS
# =============================================================================
ROOT_DIR = Path(__file__).parents[2]
RAW_DIR  = ROOT_DIR / 'data' / 'raw'
RAW_DIR.mkdir(parents=True, exist_ok=True)

CSV_COLS = [
    'timestamp', 'level_m', 'rain_1h', 'rain_3d', 'rain_7d',
    'upstream_level', 'forecast_mm', 'soil_moisture',
    'discharge_m3s', 'day_sin', 'day_cos', 'hour_sin',
]

# =============================================================================
# STATION REGISTRY
# Combines cwc_scraper.py CITY_COORDS (93 cities)
# + Bihar-specific gauge stations with precise coordinates
# =============================================================================
STATIONS: List[Dict] = [
    # ── Bihar CWC Gauge Stations (precise coordinates)
    {'name': 'Triveni',        'lat': 27.08, 'lon': 84.95, 'river': 'Gandak',       'state': 'Bihar'},
    {'name': 'Gandhighat',     'lat': 25.60, 'lon': 85.18, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Hathidah',       'lat': 25.38, 'lon': 85.84, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Buxar',          'lat': 25.57, 'lon': 83.98, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Digha',          'lat': 25.63, 'lon': 85.06, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Kursela',        'lat': 25.45, 'lon': 87.25, 'river': 'Kosi',         'state': 'Bihar'},
    {'name': 'Bhagalpur',      'lat': 25.25, 'lon': 87.01, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Kahalgaon',      'lat': 25.24, 'lon': 87.26, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Munger',         'lat': 25.38, 'lon': 86.47, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Sultanganj',     'lat': 25.25, 'lon': 86.74, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Barh',           'lat': 25.48, 'lon': 85.72, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Mokama',         'lat': 25.40, 'lon': 85.92, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Simaria',        'lat': 25.38, 'lon': 85.99, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Barauni',        'lat': 25.46, 'lon': 86.00, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Khagaria',       'lat': 25.50, 'lon': 86.47, 'river': 'Kosi',         'state': 'Bihar'},
    {'name': 'Rosera',         'lat': 25.87, 'lon': 85.98, 'river': 'Bagmati',      'state': 'Bihar'},
    {'name': 'Hayaghat',       'lat': 25.97, 'lon': 85.85, 'river': 'Bagmati',      'state': 'Bihar'},
    {'name': 'Runni_Saidpur',  'lat': 26.45, 'lon': 85.53, 'river': 'Bagmati',      'state': 'Bihar'},
    {'name': 'Dheng',          'lat': 26.37, 'lon': 85.68, 'river': 'Bagmati',      'state': 'Bihar'},
    {'name': 'Lalbegia',       'lat': 26.22, 'lon': 85.75, 'river': 'Bagmati',      'state': 'Bihar'},
    {'name': 'Muzaffarpur',    'lat': 26.12, 'lon': 85.36, 'river': 'Burhi Gandak', 'state': 'Bihar'},
    {'name': 'Sonpur',         'lat': 25.71, 'lon': 85.18, 'river': 'Gandak',       'state': 'Bihar'},
    {'name': 'Hajipur',        'lat': 25.68, 'lon': 85.21, 'river': 'Gandak',       'state': 'Bihar'},
    {'name': 'Doriganj',       'lat': 25.97, 'lon': 84.57, 'river': 'Gandak',       'state': 'Bihar'},
    {'name': 'Gopalganj',      'lat': 26.47, 'lon': 84.43, 'river': 'Gandak',       'state': 'Bihar'},
    {'name': 'Siwan',          'lat': 26.22, 'lon': 84.36, 'river': 'Gandak',       'state': 'Bihar'},
    {'name': 'Chhapra',        'lat': 25.78, 'lon': 84.74, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Revelganj',      'lat': 25.78, 'lon': 84.62, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Arrah',          'lat': 25.56, 'lon': 84.66, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Koilwar',        'lat': 25.56, 'lon': 84.79, 'river': 'Son',          'state': 'Bihar'},
    {'name': 'Patna',          'lat': 25.59, 'lon': 85.14, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Fatuha',         'lat': 25.51, 'lon': 85.32, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Begusarai',      'lat': 25.41, 'lon': 86.13, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Sahibganj',      'lat': 25.24, 'lon': 87.63, 'river': 'Ganga',        'state': 'Bihar'},
    {'name': 'Birpur',         'lat': 26.53, 'lon': 86.87, 'river': 'Kosi',         'state': 'Bihar'},
    {'name': 'Basua',          'lat': 25.86, 'lon': 86.96, 'river': 'Kosi',         'state': 'Bihar'},
    {'name': 'Dumariaghat',    'lat': 27.08, 'lon': 84.38, 'river': 'Gandak',       'state': 'Bihar'},
    {'name': 'Sripalpur',      'lat': 25.35, 'lon': 85.05, 'river': 'Punpun',       'state': 'Bihar'},
    {'name': 'Jainagar',       'lat': 26.59, 'lon': 86.23, 'river': 'Kamla',        'state': 'Bihar'},
    {'name': 'Dhengraghat',    'lat': 25.88, 'lon': 87.67, 'river': 'Mahananda',    'state': 'Bihar'},
    # ── Other major Indian flood cities from cwc_scraper.py
    {'name': 'Kolkata',        'lat': 22.57, 'lon': 88.36, 'river': 'Hooghly',       'state': 'West Bengal'},
    {'name': 'Guwahati',       'lat': 26.14, 'lon': 91.74, 'river': 'Brahmaputra',   'state': 'Assam'},
    {'name': 'Dibrugarh',      'lat': 27.48, 'lon': 94.91, 'river': 'Brahmaputra',   'state': 'Assam'},
    {'name': 'Varanasi',       'lat': 25.32, 'lon': 83.01, 'river': 'Ganga',         'state': 'Uttar Pradesh'},
    {'name': 'Gorakhpur',      'lat': 26.76, 'lon': 83.37, 'river': 'Rapti',         'state': 'Uttar Pradesh'},
    {'name': 'Cuttack',        'lat': 20.46, 'lon': 85.88, 'river': 'Mahanadi',      'state': 'Odisha'},
    {'name': 'Sambalpur',      'lat': 21.47, 'lon': 83.97, 'river': 'Mahanadi',      'state': 'Odisha'},
    {'name': 'Kochi',          'lat': 9.93,  'lon': 76.26, 'river': 'Periyar',       'state': 'Kerala'},
    {'name': 'Alappuzha',      'lat': 9.49,  'lon': 76.33, 'river': 'Pamba',         'state': 'Kerala'},
    {'name': 'Rajahmundry',    'lat': 17.00, 'lon': 81.78, 'river': 'Godavari',      'state': 'Andhra Pradesh'},
    {'name': 'Vijayawada',     'lat': 16.51, 'lon': 80.64, 'river': 'Krishna',       'state': 'Andhra Pradesh'},
    {'name': 'Srinagar',       'lat': 34.08, 'lon': 74.80, 'river': 'Jhelum',        'state': 'Jammu and Kashmir'},
    {'name': 'Haridwar',       'lat': 29.95, 'lon': 78.16, 'river': 'Ganga',         'state': 'Uttarakhand'},
    {'name': 'Delhi',          'lat': 28.61, 'lon': 77.23, 'river': 'Yamuna',        'state': 'Delhi'},
    {'name': 'Jabalpur',       'lat': 23.18, 'lon': 79.94, 'river': 'Narmada',       'state': 'Madhya Pradesh'},
    {'name': 'Surat',          'lat': 21.17, 'lon': 72.83, 'river': 'Tapi',          'state': 'Gujarat'},
    {'name': 'Kolhapur',       'lat': 16.70, 'lon': 74.24, 'river': 'Panchganga',    'state': 'Maharashtra'},
    {'name': 'Nashik',         'lat': 19.99, 'lon': 73.79, 'river': 'Godavari',      'state': 'Maharashtra'},
]

# =============================================================================
# OPEN-METEO GLOFAS — DAILY DISCHARGE
# past_days max = 92 for free tier; for full 5yr use date range
# =============================================================================
GLOFAS_URL  = 'https://flood-api.open-meteo.com/v1/flood'
ARCHIVE_URL = 'https://archive-api.open-meteo.com/v1/archive'


def _fetch_glofas_history(
    lat: float, lon: float,
    start: date, end: date,
) -> Optional[pd.DataFrame]:
    """
    Returns daily DataFrame with columns: date, discharge_m3s
    Uses Open-Meteo GloFAS Flood API (free, no key, no IP block).
    """
    url = (
        f'{GLOFAS_URL}?latitude={lat}&longitude={lon}'
        f'&daily=river_discharge'
        f'&start_date={start}&end_date={end}'
        f'&ensemble=false'
    )
    try:
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        data  = r.json()
        daily = data.get('daily', {})
        times = daily.get('time', [])
        disq  = daily.get('river_discharge', [])
        if not times or not disq:
            return None
        df = pd.DataFrame({
            'date':          pd.to_datetime(times),
            'discharge_m3s': [float(x) if x is not None else np.nan for x in disq],
        })
        df = df.dropna(subset=['discharge_m3s'])
        return df
    except Exception as e:
        print(f'  [GloFAS] ({lat},{lon}): {e}')
        return None


def _fetch_rainfall_history(
    lat: float, lon: float,
    start: date, end: date,
) -> Optional[pd.DataFrame]:
    """
    Returns hourly DataFrame with columns: timestamp, rain_1h, soil_moisture
    Uses Open-Meteo Historical Archive API (free, no key).
    """
    url = (
        f'{ARCHIVE_URL}?latitude={lat}&longitude={lon}'
        f'&hourly=precipitation,soil_moisture_0_to_7cm'
        f'&start_date={start}&end_date={end}'
        f'&timezone=Asia%2FKolkata'
    )
    try:
        r = requests.get(url, timeout=60)
        r.raise_for_status()
        data   = r.json()
        hourly = data.get('hourly', {})
        times  = hourly.get('time', [])
        precip = hourly.get('precipitation', [])
        soil   = hourly.get('soil_moisture_0_to_7cm', [])
        if not times:
            return None
        df = pd.DataFrame({
            'timestamp':    pd.to_datetime(times),
            'rain_1h':      [float(x) if x is not None else 0.0 for x in precip],
            'soil_moisture':[float(x) if x is not None else 0.3 for x in soil],
        })
        return df
    except Exception as e:
        print(f'  [Archive] ({lat},{lon}): {e}')
        return None


# =============================================================================
# FEATURE ENGINEERING
# =============================================================================
def _discharge_to_level(discharge: pd.Series) -> pd.Series:
    """
    Convert river discharge (m³/s) to approximate water level (m).
    Manning proxy: level = (Q / 50) ^ 0.6
    Same formula used in cwc_scraper.py for consistency.
    """
    return ((discharge / 50.0).clip(lower=0) ** 0.6).round(4)


def _build_features(
    station: Dict,
    glofas_df: pd.DataFrame,       # daily: date, discharge_m3s
    rain_df: Optional[pd.DataFrame],  # hourly: timestamp, rain_1h, soil_moisture
) -> pd.DataFrame:
    """
    Combines GloFAS daily discharge with hourly rainfall to produce
    one row per hour with all 11 features model_train.py expects.
    """
    # ── Upsample GloFAS daily → hourly by forward-filling
    glofas_df = glofas_df.set_index('date').sort_index()
    # Create hourly index spanning full date range
    h_start = pd.Timestamp(glofas_df.index.min())
    h_end   = pd.Timestamp(glofas_df.index.max()) + pd.Timedelta(hours=23)
    hourly_idx = pd.date_range(h_start, h_end, freq='h')

    # Resample: each day's discharge applies to all 24 hours of that day
    dis_hourly = (
        glofas_df['discharge_m3s']
        .reindex(hourly_idx, method='ffill')
        .interpolate(method='linear')
        .fillna(method='bfill')
    )

    df = pd.DataFrame({'timestamp': hourly_idx, 'discharge_m3s': dis_hourly.values})

    # ── Merge hourly rainfall
    if rain_df is not None and not rain_df.empty:
        rain_df = rain_df.set_index('timestamp').sort_index()
        df = df.set_index('timestamp')
        df['rain_1h']      = rain_df['rain_1h'].reindex(df.index, method='nearest').fillna(0.0)
        df['soil_moisture']= rain_df['soil_moisture'].reindex(df.index, method='nearest').fillna(0.3)
        df = df.reset_index()
    else:
        # Estimate from discharge seasonality if no rainfall data
        doy = df['timestamp'].dt.dayofyear
        df['rain_1h']       = (3 * np.sin(2*np.pi*doy/365 - 1.0)**6).clip(0).round(4)
        df['soil_moisture'] = (0.3 + 0.4 * np.sin(2*np.pi*doy/365 - 1.0)).clip(0,1).round(4)

    # ── Derived features
    rain_s          = pd.Series(df['rain_1h'].values)
    df['rain_3d']   = rain_s.rolling(72,  min_periods=1).sum().values.round(4)
    df['rain_7d']   = rain_s.rolling(168, min_periods=1).sum().values.round(4)
    df['level_m']   = _discharge_to_level(df['discharge_m3s'])

    # upstream_level: add small positive offset (upstream is typically higher)
    df['upstream_level'] = (df['level_m'] + np.random.uniform(0.2, 1.5, len(df))).round(4)

    # forecast_mm: use next 24h rolling sum as proxy for forecast
    df['forecast_mm'] = rain_s.rolling(24, min_periods=1).sum().shift(-24).fillna(0).values.round(4)

    # Cyclic time features
    doy              = df['timestamp'].dt.dayofyear
    hour             = df['timestamp'].dt.hour
    df['day_sin']    = np.sin(2*np.pi*doy/365).round(6)
    df['day_cos']    = np.cos(2*np.pi*doy/365).round(6)
    df['hour_sin']   = np.sin(2*np.pi*hour/24).round(6)

    # Format timestamp as ISO string
    df['timestamp']  = df['timestamp'].dt.strftime('%Y-%m-%dT%H:%M:%S')

    return df[CSV_COLS].dropna()


# =============================================================================
# DOWNLOAD ONE STATION
# =============================================================================
def download_station(
    station: Dict,
    years:   int  = 5,
    merge:   bool = True,
    verbose: bool = True,
) -> Tuple[str, int]:
    """
    Downloads historical data for one station and saves to data/raw/<name>.csv.
    Returns (station_name, rows_added).
    """
    name = station['name']
    lat  = station['lat']
    lon  = station['lon']

    end_dt   = date.today()
    start_dt = end_dt - timedelta(days=365 * years)

    if verbose:
        print(f'  Downloading {name} ({lat},{lon}) '
              f'{start_dt} → {end_dt} ...')

    # ── GloFAS discharge
    glofas_df = _fetch_glofas_history(lat, lon, start_dt, end_dt)
    if glofas_df is None or glofas_df.empty:
        if verbose:
            print(f'  [SKIP] {name}: No GloFAS data returned')
        return name, 0

    # ── Hourly rainfall (do in 1-year chunks to avoid timeout)
    rain_frames = []
    chunk_start = start_dt
    while chunk_start < end_dt:
        chunk_end = min(chunk_start + timedelta(days=365), end_dt)
        rdf = _fetch_rainfall_history(lat, lon, chunk_start, chunk_end)
        if rdf is not None:
            rain_frames.append(rdf)
        chunk_start = chunk_end + timedelta(days=1)
        time.sleep(0.3)  # gentle rate-limit

    rain_df = pd.concat(rain_frames) if rain_frames else None

    # ── Build feature matrix
    df = _build_features(station, glofas_df, rain_df)

    if df.empty:
        if verbose:
            print(f'  [SKIP] {name}: Empty after feature build')
        return name, 0

    # ── Save / merge
    safe_name = name.replace('/', '_').replace(' ', '_')
    path      = RAW_DIR / f'{safe_name}.csv'
    rows_added = len(df)

    if merge and path.exists():
        try:
            existing  = pd.read_csv(path)
            existing_ts = set(existing['timestamp'].values)
            new_rows  = df[~df['timestamp'].isin(existing_ts)]
            if not new_rows.empty:
                combined = pd.concat([existing, new_rows], ignore_index=True)
                combined = combined.drop_duplicates('timestamp').sort_values('timestamp')
                combined[CSV_COLS].to_csv(path, index=False)
                rows_added = len(new_rows)
                if verbose:
                    print(f'  ✓ {name}: +{rows_added} new rows '
                          f'(total {len(combined):,})')
            else:
                if verbose:
                    print(f'  ✓ {name}: already up to date ({len(existing):,} rows)')
                rows_added = 0
        except Exception as e:
            print(f'  [WARN] merge failed for {name}: {e} — overwriting')
            df[CSV_COLS].to_csv(path, index=False)
    else:
        df[CSV_COLS].to_csv(path, index=False)
        if verbose:
            print(f'  ✓ {name}: {rows_added:,} rows → {path.name}')

    return name, rows_added


# =============================================================================
# DOWNLOAD ALL
# =============================================================================
def download_all(
    years:    int  = 5,
    merge:    bool = True,
    workers:  int  = 6,
    stations: Optional[List[Dict]] = None,
):
    targets = stations or STATIONS
    print(f'\nOpsFlood Historical Downloader')
    print(f'  Stations : {len(targets)}')
    print(f'  Period   : {years} years ({date.today() - timedelta(days=365*years)} → today)')
    print(f'  Workers  : {workers} parallel')
    print(f'  Output   : {RAW_DIR}\n')

    results = []
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futures = {
            ex.submit(download_station, s, years, merge, False): s
            for s in targets
        }
        for fut in tqdm(as_completed(futures), total=len(futures),
                        desc='Downloading', unit='stn'):
            st = futures[fut]
            try:
                name, rows = fut.result()
                results.append({'station': name, 'rows': rows})
            except Exception as e:
                results.append({'station': st['name'], 'rows': 0, 'error': str(e)})
                print(f'  [ERROR] {st["name"]}: {e}')

    # ── Summary
    ok       = [r for r in results if r['rows'] > 0]
    total    = sum(r['rows'] for r in ok)
    print(f'\n{═ Done {═ "="*50}')
    print(f'  Downloaded : {len(ok)}/{len(targets)} stations')
    print(f'  Total rows : {total:,}  (~{total/len(ok):.0f} rows/station)' if ok else '')
    print(f'  Output     : {RAW_DIR}')
    print(f'\nNext step: python -m backend.ml.model_train --station all --plot')


# =============================================================================
# STATUS
# =============================================================================
def show_status():
    csvs = sorted(RAW_DIR.glob('*.csv'))
    if not csvs:
        print('No data yet. Run:')
        print('  python -m backend.ml.historical_downloader --download')
        return

    print(f'\n{"Station":<35} {"Rows":>8}  {"From":<12}  {"To":<12}  {"Ready"}')
    print('-' * 85)
    total_rows = 0
    for p in csvs:
        try:
            df     = pd.read_csv(p, usecols=['timestamp'])
            n      = len(df)
            frm    = str(df['timestamp'].iloc[0])[:10]  if n else ''
            to     = str(df['timestamp'].iloc[-1])[:10] if n else ''
            ready  = '✓' if n >= 500 else f'need {500-n}'
            total_rows += n
            print(f'{p.stem:<35} {n:>8}  {frm:<12}  {to:<12}  {ready}')
        except Exception as e:
            print(f'{p.stem:<35}  ERROR: {e}')
    print('-' * 85)
    print(f'Total: {len(csvs)} stations, {total_rows:,} rows\n')


# =============================================================================
# MAIN
# =============================================================================
def main():
    ap = argparse.ArgumentParser(
        description='OpsFlood Historical Data Downloader — 5-year GloFAS + IMD rainfall'
    )
    ap.add_argument('--download',  action='store_true',
                    help='Download all stations')
    ap.add_argument('--station',   default='',
                    help='Download a single station by name')
    ap.add_argument('--years',     type=int, default=5,
                    help='Years of history to fetch (default 5)')
    ap.add_argument('--merge',     action='store_true', default=True,
                    help='Merge with existing CSVs (default true)')
    ap.add_argument('--no-merge',  action='store_false', dest='merge',
                    help='Overwrite existing CSVs')
    ap.add_argument('--workers',   type=int, default=6,
                    help='Parallel download workers (default 6)')
    ap.add_argument('--status',    action='store_true',
                    help='Show existing CSV coverage')
    args = ap.parse_args()

    if args.status:
        show_status()
        return

    if args.station:
        matches = [s for s in STATIONS
                   if s['name'].lower() == args.station.lower()]
        if not matches:
            # fuzzy match
            matches = [s for s in STATIONS
                       if args.station.lower() in s['name'].lower()]
        if not matches:
            print(f'Station "{args.station}" not found. Available:')
            for s in STATIONS:
                print(f'  {s["name"]}')
            sys.exit(1)
        for s in matches:
            download_station(s, years=args.years, merge=args.merge, verbose=True)
        return

    if args.download:
        download_all(
            years=args.years,
            merge=args.merge,
            workers=args.workers,
        )
        return

    # Default: show status
    show_status()
    print('\nTo download: python -m backend.ml.historical_downloader --download')


if __name__ == '__main__':
    main()
