# backend/ml/flood_predictor.py
# OpsFlood — BiLSTM+Attention Flood Prediction Engine
#
# COORDINATE SYSTEM
#   Stations with real CWC CSV data (e.g. Gandhighat) store level_m in metres
#   above a LOCAL GAUGE DATUM, not MSL. GAUGE_THRESHOLDS stores MSL elevations.
#   gauge_zero = MSL elevation of the gauge staff zero (datum).
#
#   Input pipeline:  current_level_MSL  -> (- gauge_zero) -> gauge_m -> RobustScaler
#   Output pipeline: model_out (scaled) -> inverse_scaler -> gauge_m -> (+ gauge_zero) -> MSL
#
#   Stations trained on synthetic data have gauge_zero=0 (synthetic used raw MSL).
from __future__ import annotations

import json
import math
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Optional

import numpy as np

# ── Paths ───────────────────────────────────────────────────────────────────
MODEL_DIR  = Path(os.getenv('MODEL_DIR',  Path(__file__).parent / 'saved_models'))
SCALER_DIR = Path(os.getenv('SCALER_DIR', Path(__file__).parent / 'scalers'))

FEATURES = [
    'level_m', 'rain_1h', 'rain_3d', 'rain_7d', 'upstream_level',
    'forecast_mm', 'soil_moisture', 'discharge_m3s',
    'day_sin', 'day_cos', 'hour_sin',
]
N_FEATURES = len(FEATURES)  # 11
SEQ_LEN    = 24
FORECAST_H = 72

# ── Gauge thresholds (MSL metres) + gauge datum zero ────────────────────────────
#
# gauge_zero: MSL elevation of staff gauge zero for stations that have real
#             CWC CSV data.  0.0 for stations trained on synthetic data
#             (synthetic already uses raw MSL metres matching thresholds).
#
# Gandhighat gauge_zero derived from:
#   danger_MSL=48.60, CSV max level_m=0.921  => zero ~ 48.60-0.921 = 47.679m
GAUGE_THRESHOLDS: dict[str, dict] = {
    'Gandhighat':     {'danger': 48.60, 'warning': 47.50, 'river': 'Ganga',        'gauge_zero': 47.68},
    'Dighaghat':      {'danger': 50.45, 'warning': 49.30, 'river': 'Ganga',        'gauge_zero': 0.0},
    'Hathidah':       {'danger': 41.76, 'warning': 40.50, 'river': 'Ganga',        'gauge_zero': 0.0},
    'Munger':         {'danger': 39.33, 'warning': 38.20, 'river': 'Ganga',        'gauge_zero': 0.0},
    'Kahalgaon':      {'danger': 31.09, 'warning': 30.00, 'river': 'Ganga',        'gauge_zero': 0.0},
    'Bhagalpur':      {'danger': 33.68, 'warning': 32.50, 'river': 'Ganga',        'gauge_zero': 0.0},
    'Buxar':          {'danger': 60.30, 'warning': 59.20, 'river': 'Ganga',        'gauge_zero': 0.0},
    'Birpur (CWC)':   {'danger': 74.70, 'warning': 73.70, 'river': 'Kosi',         'gauge_zero': 0.0},
    'Baltara':        {'danger': 33.85, 'warning': 32.85, 'river': 'Kosi',         'gauge_zero': 0.0},
    'Basua':          {'danger': 47.75, 'warning': 46.50, 'river': 'Kosi',         'gauge_zero': 0.0},
    'Kursela':        {'danger': 30.00, 'warning': 28.80, 'river': 'Kosi',         'gauge_zero': 0.0},
    'Chatia':         {'danger': 69.15, 'warning': 68.10, 'river': 'Gandak',       'gauge_zero': 0.0},
    'Dumariaghat':    {'danger': 62.22, 'warning': 61.10, 'river': 'Gandak',       'gauge_zero': 0.0},
    'Rewaghat':       {'danger': 54.41, 'warning': 53.40, 'river': 'Gandak',       'gauge_zero': 0.0},
    'Hajipur':        {'danger': 50.32, 'warning': 49.40, 'river': 'Gandak',       'gauge_zero': 0.0},
    'Dheng Bridge':   {'danger': 71.00, 'warning': 70.00, 'river': 'Bagmati',      'gauge_zero': 0.0},
    'Benibad':        {'danger': 48.68, 'warning': 47.68, 'river': 'Bagmati',      'gauge_zero': 0.0},
    'Hayaghat':       {'danger': 45.72, 'warning': 44.50, 'river': 'Bagmati',      'gauge_zero': 0.0},
    'Sikandarpur':    {'danger': 52.53, 'warning': 51.40, 'river': 'Burhi Gandak', 'gauge_zero': 0.0},
    'Samastipur':     {'danger': 46.00, 'warning': 44.80, 'river': 'Burhi Gandak', 'gauge_zero': 0.0},
    'Rosera':         {'danger': 42.63, 'warning': 41.50, 'river': 'Burhi Gandak', 'gauge_zero': 0.0},
    'Khagaria':       {'danger': 36.58, 'warning': 35.40, 'river': 'Burhi Gandak', 'gauge_zero': 0.0},
    'Darauli':        {'danger': 60.82, 'warning': 59.80, 'river': 'Ghaghra',      'gauge_zero': 0.0},
    'Gangpur Siswan': {'danger': 57.04, 'warning': 56.00, 'river': 'Ghaghra',      'gauge_zero': 0.0},
    'Dhengraghat':    {'danger': 35.65, 'warning': 34.65, 'river': 'Mahananda',    'gauge_zero': 0.0},
    'Taibpur':        {'danger': 66.00, 'warning': 64.80, 'river': 'Mahananda',    'gauge_zero': 0.0},
    'Jainagar':       {'danger': 67.75, 'warning': 66.00, 'river': 'Kamla',        'gauge_zero': 0.0},
    'Jhanjharpur':    {'danger': 50.00, 'warning': 48.80, 'river': 'Kamalabalan',  'gauge_zero': 0.0},
    'Sonbarsa':       {'danger': 81.85, 'warning': 80.70, 'river': 'Adhwara',      'gauge_zero': 0.0},
    'Kamtaul':        {'danger': 50.00, 'warning': 49.00, 'river': 'Adhwara',      'gauge_zero': 0.0},
    'Sripalpur':      {'danger': 50.60, 'warning': 49.50, 'river': 'Punpun',       'gauge_zero': 0.0},
}


# ── Build model matching model_train.py exactly ─────────────────────────────────
def _build_model():
    try:
    import torch
    _TORCH_AVAILABLE = True
except ImportError:
    torch = None
    _TORCH_AVAILABLE = False.nn as nn

    class _Model(nn.Module):
        def __init__(self):
            super().__init__()
            self.bilstm1 = nn.LSTM(N_FEATURES, 128, num_layers=1,
                                   batch_first=True, bidirectional=True)
            self.drop1   = nn.Dropout(0.25)
            self.attn    = nn.MultiheadAttention(embed_dim=256, num_heads=4,
                                                  dropout=0.1, batch_first=True)
            self.norm1   = nn.LayerNorm(256)
            self.bilstm2 = nn.LSTM(256, 64, num_layers=1,
                                   batch_first=True, bidirectional=True)
            self.drop2   = nn.Dropout(0.2)
            self.fc1     = nn.Linear(128, 256)
            self.act1    = nn.GELU()
            self.fc2     = nn.Linear(256, 128)
            self.act2    = nn.GELU()
            self.out     = nn.Linear(128, FORECAST_H)

        def forward(self, x):
            h1, _ = self.bilstm1(x)
            h1     = self.drop1(h1)
            a,  _  = self.attn(h1, h1, h1)
            h1     = self.norm1(h1 + a)
            h2, _ = self.bilstm2(h1)
            h2     = self.drop2(h2)
            h2     = h2[:, -1, :]
            out    = self.act1(self.fc1(h2))
            out    = self.act2(self.fc2(out))
            return self.out(out)  # (B, 72)

    return _Model()


# ── FloodPredictor ─────────────────────────────────────────────────────────────────
class FloodPredictor:
    """
    BiLSTM+Attention flood level predictor for Bihar gauge stations.

    All public API levels are in MSL metres (same as GAUGE_THRESHOLDS).
    Internal gauge conversion is handled transparently via gauge_zero.
    """

    def __init__(self, station: str):
        self.station     = station
        self.threshold   = GAUGE_THRESHOLDS.get(station, {'danger': 50.0, 'warning': 48.0, 'gauge_zero': 0.0})
        self.gauge_zero  = self.threshold.get('gauge_zero', 0.0)
        self._model, self._scaler, self._config = self._load_model(station)

    # ── Public API ───────────────────────────────────────────────────────────
    def predict(
        self,
        current_level:   float,          # MSL metres
        rainfall_3d_mm:  float,
        rainfall_7d_mm:  float,
        upstream_level:  Optional[float] = None,  # MSL metres
        imd_forecast_mm: float = 0.0,
        history:         Optional[List[float]] = None,  # MSL metres list
    ) -> dict:
        now = datetime.now(timezone.utc)

        if self._model is not None and self._scaler is not None:
            points = self._ml_predict(
                current_level, rainfall_3d_mm, rainfall_7d_mm,
                upstream_level, imd_forecast_mm, now, history)
        else:
            points = self._physics_predict(current_level, rainfall_3d_mm, now)

        next_24h = points[:24]
        next_48h = points[:48]
        next_72h = points[:72]
        peak       = max(p['level'] for p in next_72h) if next_72h else current_level
        confidence = 85.0 if self._model is not None else 65.0

        return {
            'station':            self.station,
            'current_level':      current_level,
            'danger_level':       self.threshold['danger'],
            'warning_level':      self.threshold['warning'],
            'next_24h':           next_24h,
            'next_48h':           next_48h,
            'next_72h':           next_72h,
            'peak_level':         round(peak, 3),
            'will_breach_danger': peak >= self.threshold['danger'],
            'confidence_pct':     confidence,
            'model_version':      'v2.1-bilstm' if self._model else 'v1.0-physics',
        }

    # ── PyTorch ML inference ──────────────────────────────────────────────────
    def _ml_predict(
        self,
        current: float,           # MSL metres
        r3d: float,
        r7d: float,
        upstream: Optional[float],  # MSL metres or None
        imd_fcst: float,
        now: datetime,
        history: Optional[List[float]],  # MSL metres
    ) -> list:
        import torch

        gz         = self.gauge_zero
        # Convert MSL -> gauge metres for model input
        current_g  = current  - gz
        upstream_g = (upstream - gz) if upstream is not None else current_g
        history_g  = [h - gz for h in history] if history else None

        level_win  = self._build_history_window(current_g, r3d, history_g)  # gauge metres

        doy      = now.timetuple().tm_yday
        hour     = now.hour
        day_sin  = math.sin(2 * math.pi * doy / 365)
        day_cos  = math.cos(2 * math.pi * doy / 365)
        hour_sin = math.sin(2 * math.pi * hour / 24)

        # Scaler was fit on gauge metres directly — no /danger normalisation needed
        raw_seq = np.array(
            [
                [
                    level_win[t],        # level_m in gauge metres
                    r3d / 72.0,          # rain_1h (approx)
                    r3d,                 # rain_3d mm
                    r7d,                 # rain_7d mm
                    upstream_g,          # upstream_level in gauge metres
                    imd_fcst,            # forecast_mm
                    float(self._scaler.center_[6]),  # soil_moisture median
                    float(self._scaler.center_[7]),  # discharge_m3s median
                    day_sin,
                    day_cos,
                    hour_sin,
                ]
                for t in range(SEQ_LEN)
            ],
            dtype=np.float64,
        )  # (24, 11)

        scaled_seq = self._scaler.transform(raw_seq)  # (24, 11)
        x = torch.tensor(scaled_seq, dtype=torch.float32).unsqueeze(0)  # (1,24,11)

        self._model.eval()
        with torch.no_grad():
            out = self._model(x).squeeze(0).numpy()  # (72,) scaled

        # Inverse RobustScaler for level_m (col 0): gauge_m = out*scale_[0] + center_[0]
        c0, s0   = float(self._scaler.center_[0]), float(self._scaler.scale_[0])
        gauge_levels = out * s0 + c0          # (72,) gauge metres
        msl_levels   = gauge_levels + gz      # (72,) MSL metres

        return [
            {
                'time':      (now + timedelta(hours=i + 1)).isoformat(),
                'level':     round(float(msl_levels[i]), 3),
                'precip_mm': round(float(max(0.0, imd_fcst * (1 + 0.1 * math.sin(i)))), 1),
            }
            for i in range(FORECAST_H)
        ]

    # ── History window (gauge metres) ──────────────────────────────────────────────
    def _build_history_window(
        self,
        current_gauge: float,       # gauge metres
        rainfall_3d_mm: float,
        history_gauge: Optional[List[float]],  # gauge metres
    ) -> List[float]:
        """Returns SEQ_LEN gauge-metre readings (oldest→newest)."""
        if history_gauge and len(history_gauge) >= SEQ_LEN:
            return list(history_gauge[-SEQ_LEN:])
        rate    = 0.025 if rainfall_3d_mm > 100 else 0.008
        partial = list(history_gauge) if history_gauge else []
        n_miss  = SEQ_LEN - len(partial)
        oldest  = partial[0] if partial else current_gauge
        return [oldest - rate * (n_miss - t) for t in range(n_miss)] + partial

    # ── Physics fallback (MSL metres) ────────────────────────────────────────────
    def _physics_predict(self, current: float, rainfall_3d_mm: float, now: datetime) -> list:
        rate = 0.025 if rainfall_3d_mm > 100 else 0.008
        return [
            {
                'time':      (now + timedelta(hours=i + 1)).isoformat(),
                'level':     round(
                    current + rate * (i + 1) + 0.06 * math.sin(2 * math.pi * (i + 1) / 24),
                    3),
                'precip_mm': round(max(0.0, rainfall_3d_mm / 3 - i * 0.5), 1),
            }
            for i in range(FORECAST_H)
        ]

    # ── Model loading ─────────────────────────────────────────────────────────────
    def _load_model(self, station: str):
        try:
            import torch
            import joblib as jl

            sname    = station.replace(' ', '_')
            pt_path  = MODEL_DIR  / f'{station}_bilstm.pt'
            sc_path  = SCALER_DIR / f'{station}_scaler.joblib'
            if not pt_path.exists():
                pt_path = MODEL_DIR / f'{sname}_bilstm.pt'
            if not sc_path.exists():
                sc_path = SCALER_DIR / f'{sname}_scaler.joblib'

            if not pt_path.exists():
                return None, None, None

            bundle = torch.load(str(pt_path), map_location='cpu', weights_only=False)
            model  = _build_model()
            model.load_state_dict(bundle['model_state'])
            model.eval()

            scaler = jl.load(str(sc_path)) if sc_path.exists() else None
            config = bundle.get('config', {})
            print(f'\u2705 FloodPredictor: loaded {station} '
                  f'(gauge_zero={self.gauge_zero}m, scaler={sc_path.exists()})')
            return model, scaler, config

        except Exception as exc:
            print(f'\u26a0\ufe0f FloodPredictor: could not load {station}: {exc}')
        return None, None, None


# ── Convenience function ────────────────────────────────────────────────────────────
def get_prediction_json(
    station: str,
    current_level: float,
    rainfall_3d_mm: float = 0.0,
    rainfall_7d_mm: float = 0.0,
    upstream_level: Optional[float] = None,
    imd_forecast_mm: float = 0.0,
    history: Optional[List[float]] = None,
) -> str:
    predictor = FloodPredictor(station)
    result = predictor.predict(
        current_level, rainfall_3d_mm, rainfall_7d_mm,
        upstream_level, imd_forecast_mm, history)
    return json.dumps(result)
