# backend/ml/flood_predictor.py
# OpsFlood — BiLSTM+Attention Flood Prediction Engine
#
# Architecture matches ml/model_train.py exactly:
#   bilstm1:  LSTM(input=11, hidden=128, bidir)  -> drop(0.25) -> (B,24,256)
#   attn:     MultiheadAttention(256, heads=4)   -> residual+norm -> (B,24,256)
#   bilstm2:  LSTM(input=256, hidden=64, bidir)  -> drop(0.2)  -> last step (B,128)
#   fc1:      Linear(128,256) + GELU
#   fc2:      Linear(256,128) + GELU
#   out:      Linear(128,72)
#
# Normalisation: per-station RobustScaler (all 11 features together)
# Output denorm: scaler.inverse_transform on level_m column (col 0)
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

# 11 features in order (matches FEATURES list in model_train.py)
FEATURES = [
    'level_m', 'rain_1h', 'rain_3d', 'rain_7d', 'upstream_level',
    'forecast_mm', 'soil_moisture', 'discharge_m3s',
    'day_sin', 'day_cos', 'hour_sin',
]
N_FEATURES = len(FEATURES)  # 11
SEQ_LEN    = 24
FORECAST_H = 72

# ── Gauge thresholds ───────────────────────────────────────────────────────────
GAUGE_THRESHOLDS: dict[str, dict] = {
    'Gandhighat':     {'danger': 48.60, 'warning': 47.50, 'river': 'Ganga'},
    'Dighaghat':      {'danger': 50.45, 'warning': 49.30, 'river': 'Ganga'},
    'Hathidah':       {'danger': 41.76, 'warning': 40.50, 'river': 'Ganga'},
    'Munger':         {'danger': 39.33, 'warning': 38.20, 'river': 'Ganga'},
    'Kahalgaon':      {'danger': 31.09, 'warning': 30.00, 'river': 'Ganga'},
    'Bhagalpur':      {'danger': 33.68, 'warning': 32.50, 'river': 'Ganga'},
    'Buxar':          {'danger': 60.30, 'warning': 59.20, 'river': 'Ganga'},
    'Birpur (CWC)':   {'danger': 74.70, 'warning': 73.70, 'river': 'Kosi'},
    'Baltara':        {'danger': 33.85, 'warning': 32.85, 'river': 'Kosi'},
    'Basua':          {'danger': 47.75, 'warning': 46.50, 'river': 'Kosi'},
    'Kursela':        {'danger': 30.00, 'warning': 28.80, 'river': 'Kosi'},
    'Chatia':         {'danger': 69.15, 'warning': 68.10, 'river': 'Gandak'},
    'Dumariaghat':    {'danger': 62.22, 'warning': 61.10, 'river': 'Gandak'},
    'Rewaghat':       {'danger': 54.41, 'warning': 53.40, 'river': 'Gandak'},
    'Hajipur':        {'danger': 50.32, 'warning': 49.40, 'river': 'Gandak'},
    'Dheng Bridge':   {'danger': 71.00, 'warning': 70.00, 'river': 'Bagmati'},
    'Benibad':        {'danger': 48.68, 'warning': 47.68, 'river': 'Bagmati'},
    'Hayaghat':       {'danger': 45.72, 'warning': 44.50, 'river': 'Bagmati'},
    'Sikandarpur':    {'danger': 52.53, 'warning': 51.40, 'river': 'Burhi Gandak'},
    'Samastipur':     {'danger': 46.00, 'warning': 44.80, 'river': 'Burhi Gandak'},
    'Rosera':         {'danger': 42.63, 'warning': 41.50, 'river': 'Burhi Gandak'},
    'Khagaria':       {'danger': 36.58, 'warning': 35.40, 'river': 'Burhi Gandak'},
    'Darauli':        {'danger': 60.82, 'warning': 59.80, 'river': 'Ghaghra'},
    'Gangpur Siswan': {'danger': 57.04, 'warning': 56.00, 'river': 'Ghaghra'},
    'Dhengraghat':    {'danger': 35.65, 'warning': 34.65, 'river': 'Mahananda'},
    'Taibpur':        {'danger': 66.00, 'warning': 64.80, 'river': 'Mahananda'},
    'Jainagar':       {'danger': 67.75, 'warning': 66.00, 'river': 'Kamla'},
    'Jhanjharpur':    {'danger': 50.00, 'warning': 48.80, 'river': 'Kamalabalan'},
    'Sonbarsa':       {'danger': 81.85, 'warning': 80.70, 'river': 'Adhwara'},
    'Kamtaul':        {'danger': 50.00, 'warning': 49.00, 'river': 'Adhwara'},
    'Sripalpur':      {'danger': 50.60, 'warning': 49.50, 'river': 'Punpun'},
}


# ── Build model matching model_train.py exactly ─────────────────────────────────
def _build_model():
    import torch.nn as nn

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
            h1     = self.norm1(h1 + a)          # residual connection
            h2, _ = self.bilstm2(h1)
            h2     = self.drop2(h2)
            h2     = h2[:, -1, :]                # last timestep
            out    = self.act1(self.fc1(h2))
            out    = self.act2(self.fc2(out))
            return self.out(out)                 # (B, 72)

    return _Model()


# ── FloodPredictor ─────────────────────────────────────────────────────────────────
class FloodPredictor:
    """
    BiLSTM+Attention flood level predictor for Bihar gauge stations.
    Uses per-station RobustScaler for feature normalisation/denormalisation.
    Falls back to physics-based trend model when PyTorch model is unavailable.
    """

    def __init__(self, station: str):
        self.station    = station
        self.threshold  = GAUGE_THRESHOLDS.get(station, {'danger': 50.0, 'warning': 48.0})
        self._model, self._scaler, self._config = self._load_model(station)

    # ── Public API ───────────────────────────────────────────────────────────
    def predict(
        self,
        current_level:   float,
        rainfall_3d_mm:  float,
        rainfall_7d_mm:  float,
        upstream_level:  Optional[float] = None,
        imd_forecast_mm: float = 0.0,
        history:         Optional[List[float]] = None,
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
        current: float,
        r3d: float,
        r7d: float,
        upstream: Optional[float],
        imd_fcst: float,
        now: datetime,
        history: Optional[List[float]],
    ) -> list:
        import torch

        upstream_v  = upstream if upstream is not None else current
        level_win   = self._build_history_window(current, r3d, history)

        doy      = now.timetuple().tm_yday
        hour     = now.hour
        day_sin  = math.sin(2 * math.pi * doy / 365)
        day_cos  = math.cos(2 * math.pi * doy / 365)
        hour_sin = math.sin(2 * math.pi * hour / 24)

        # Build raw feature matrix (SEQ_LEN, 11) then scale with station scaler
        raw_seq = np.array(
            [
                [
                    level_win[t],     # level_m
                    r3d / 72.0,       # rain_1h  (approx from 3d total)
                    r3d,              # rain_3d
                    r7d,              # rain_7d
                    upstream_v,       # upstream_level
                    imd_fcst,         # forecast_mm
                    0.261,            # soil_moisture (station median from scaler center_)
                    1.94,             # discharge_m3s (station median)
                    day_sin,
                    day_cos,
                    hour_sin,
                ]
                for t in range(SEQ_LEN)
            ],
            dtype=np.float64,
        )  # (24, 11)

        scaled_seq = self._scaler.transform(raw_seq)  # (24, 11)
        x = torch.tensor(scaled_seq, dtype=torch.float32).unsqueeze(0)  # (1, 24, 11)

        self._model.eval()
        with torch.no_grad():
            out = self._model(x).squeeze(0).numpy()  # (72,)

        # De-normalise: model output is scaled level_m — inverse via col 0 of scaler
        dummy          = np.zeros((FORECAST_H, N_FEATURES), dtype=np.float64)
        dummy[:, 0]    = out
        levels         = self._scaler.inverse_transform(dummy)[:, 0]

        return [
            {
                'time':      (now + timedelta(hours=i + 1)).isoformat(),
                'level':     round(float(levels[i]), 3),
                'precip_mm': round(float(max(0.0, imd_fcst * (1 + 0.1 * math.sin(i)))), 1),
            }
            for i in range(FORECAST_H)
        ]

    # ── History window ─────────────────────────────────────────────────────────────
    def _build_history_window(
        self,
        current_level: float,
        rainfall_3d_mm: float,
        history: Optional[List[float]],
    ) -> List[float]:
        if history and len(history) >= SEQ_LEN:
            return list(history[-SEQ_LEN:])
        rate    = 0.025 if rainfall_3d_mm > 100 else 0.008
        partial = list(history) if history else []
        n_miss  = SEQ_LEN - len(partial)
        oldest  = partial[0] if partial else current_level
        return [oldest - rate * (n_miss - t) for t in range(n_miss)] + partial

    # ── Physics fallback ───────────────────────────────────────────────────────────
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
        """
        Load per-station .pt model + _scaler.joblib.
        Returns (model, scaler, config) or (None, None, None) on failure.
        """
        try:
            import torch
            import joblib as jl

            # Normalise station name for file lookup
            sname    = station.replace(' ', '_')
            pt_path  = MODEL_DIR  / f'{station}_bilstm.pt'
            sc_path  = SCALER_DIR / f'{station}_scaler.joblib'
            if not pt_path.exists():
                pt_path = MODEL_DIR / f'{sname}_bilstm.pt'
            if not sc_path.exists():
                sc_path = SCALER_DIR / f'{sname}_scaler.joblib'

            if not pt_path.exists():
                return None, None, None

            bundle  = torch.load(str(pt_path), map_location='cpu', weights_only=False)
            model   = _build_model()
            model.load_state_dict(bundle['model_state'])
            model.eval()

            scaler = jl.load(str(sc_path)) if sc_path.exists() else None
            config = bundle.get('config', {})
            print(f'\u2705 FloodPredictor: loaded {station} (bilstm + scaler={sc_path.exists()})')
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
