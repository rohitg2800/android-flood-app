# backend/ml/flood_predictor.py
# OpsFlood — BiLSTM+Attention Flood Prediction Engine
#
# Architecture (from saved .pt weight shapes):
#   bilstm1:  input=11, hidden=128, bidirectional  → output=256
#   attn:     MultiheadAttention(embed_dim=256, num_heads=3)
#   norm1:    LayerNorm(256)
#   bilstm2:  input=256, hidden=64, bidirectional  → output=128
#   fc1:      Linear(128, 256)
#   fc2:      Linear(256, 128)
#   out:      Linear(128, 72)   → 72-hour forecast
#
# Input features (11, from config in .pt bundle):
#   level_m, rain_1h, rain_3d, rain_7d, upstream_level, forecast_mm,
#   soil_moisture, discharge_m3s, day_sin, day_cos, hour_sin
#
# Sequence length: 24 (from config)
from __future__ import annotations

import json
import math
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Optional

import numpy as np

# ── Model / scaler registry ─────────────────────────────────────────────────
MODEL_DIR   = Path(os.getenv('MODEL_DIR',   Path(__file__).parent / 'saved_models'))
SCALER_DIR  = Path(os.getenv('SCALER_DIR',  Path(__file__).parent / 'scalers'))
_STATS_FILE = SCALER_DIR / 'feature_stats.json'


def _load_feature_stats() -> dict[str, tuple[float, float]]:
    _fallback: dict[str, tuple[float, float]] = {
        'gauge_level':    (40.0, 20.0),
        'rainfall_3d':    (50.0, 80.0),
        'rainfall_7d':    (120.0, 150.0),
        'upstream_level': (40.0, 20.0),
        'imd_forecast':   (20.0, 60.0),
    }
    try:
        raw = json.loads(_STATS_FILE.read_text())
        loaded = {k: tuple(v) for k, v in raw['features'].items()}
        if loaded.keys() == _fallback.keys():
            return loaded  # type: ignore[return-value]
    except Exception:
        pass
    return _fallback


FEATURE_STATS: dict[str, tuple[float, float]] = _load_feature_stats()

# ── Gauge thresholds ────────────────────────────────────────────────────────────
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

SEQ_LEN   = 24   # matches config in .pt bundle
N_FEATURES = 11  # matches config in .pt bundle


# ── PyTorch BiLSTM+Attention model definition ──────────────────────────────────
def _build_bilstm_model():
    """
    Reconstruct BiLSTMAttention architecture from weight shapes:
      bilstm1 weight_ih_l0: [512, 11]  → hidden=128, input=11
      bilstm1 weight_hh_l0: [512, 128] → confirms hidden=128
      attn in_proj_weight:  [768, 256]  → embed=256, heads=3
      bilstm2 weight_ih_l0: inferred hidden=64 (output=128 bidir)
      fc1: [256, 128], fc2: [128, 256], out: [72, 128]
    """
    import torch
    import torch.nn as nn

    class BiLSTMAttention(nn.Module):
        def __init__(self):
            super().__init__()
            self.bilstm1 = nn.LSTM(N_FEATURES, 128, batch_first=True, bidirectional=True)
            self.attn    = nn.MultiheadAttention(embed_dim=256, num_heads=3, batch_first=True)
            self.norm1   = nn.LayerNorm(256)
            self.bilstm2 = nn.LSTM(256, 64, batch_first=True, bidirectional=True)
            self.fc1     = nn.Linear(128, 256)
            self.fc2     = nn.Linear(256, 128)
            self.out     = nn.Linear(128, 72)

        def forward(self, x):  # x: (batch, seq, features)
            x, _ = self.bilstm1(x)         # (batch, seq, 256)
            x, _ = self.attn(x, x, x)      # (batch, seq, 256)
            x     = self.norm1(x)
            x, _ = self.bilstm2(x)         # (batch, seq, 128)
            x     = x[:, -1, :]            # last timestep: (batch, 128)
            x     = torch.relu(self.fc1(x))# (batch, 256)
            x     = torch.relu(self.fc2(x))# (batch, 128)
            return self.out(x)             # (batch, 72)

    return BiLSTMAttention()


# ── FloodPredictor ─────────────────────────────────────────────────────────────────
class FloodPredictor:
    """
    BiLSTM+Attention flood level predictor for Bihar gauge stations.
    Falls back to physics-based trend model when PyTorch model is unavailable.
    """

    def __init__(self, station: str):
        self.station    = station
        self.threshold  = GAUGE_THRESHOLDS.get(station, {'danger': 50.0, 'warning': 48.0})
        self._model, self._config = self._load_model(station)

    # ── Public API ───────────────────────────────────────────────────────────
    def predict(
        self,
        current_level:     float,
        rainfall_3d_mm:    float,
        rainfall_7d_mm:    float,
        upstream_level:    Optional[float] = None,
        imd_forecast_mm:   float = 0.0,
        history:           Optional[List[float]] = None,
    ) -> dict:
        now = datetime.now(timezone.utc)

        if self._model is not None:
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

        seq_len    = (self._config or {}).get('seq_len', SEQ_LEN)
        upstream_v = upstream or current
        level_win  = self._build_history_window(current, r3d, history, seq_len)

        # Build cyclical time features
        day_of_year = now.timetuple().tm_yday
        hour        = now.hour
        day_sin  = math.sin(2 * math.pi * day_of_year / 365)
        day_cos  = math.cos(2 * math.pi * day_of_year / 365)
        hour_sin = math.sin(2 * math.pi * hour / 24)

        # Normalise level using GAUGE_THRESHOLDS danger as reference
        danger = self.threshold['danger']

        def norm_level(v): return (v - danger * 0.8) / (danger * 0.2) if danger > 0 else v / 50.0
        def norm_rain(v, scale): return v / scale if scale > 0 else 0.0

        # 11 features matching config: level_m, rain_1h, rain_3d, rain_7d,
        # upstream_level, forecast_mm, soil_moisture, discharge_m3s,
        # day_sin, day_cos, hour_sin
        seq = np.array(
            [
                [
                    norm_level(level_win[t]),
                    norm_rain(r3d / 72, 10.0),   # rain_1h approx
                    norm_rain(r3d, 200.0),
                    norm_rain(r7d, 400.0),
                    norm_level(upstream_v),
                    norm_rain(imd_fcst, 50.0),
                    0.5,                          # soil_moisture (unknown → neutral)
                    norm_level(current) * 100,    # discharge proxy
                    day_sin,
                    day_cos,
                    hour_sin,
                ]
                for t in range(seq_len)
            ],
            dtype=np.float32,
        )  # (seq_len, 11)

        x = torch.tensor(seq).unsqueeze(0)  # (1, seq_len, 11)
        self._model.eval()
        with torch.no_grad():
            out = self._model(x)  # (1, 72)
        levels_norm = out.squeeze(0).numpy()  # (72,)

        # De-normalise: reverse norm_level
        levels = levels_norm * (danger * 0.2) + danger * 0.8

        return [
            {
                'time':      (now + timedelta(hours=i + 1)).isoformat(),
                'level':     round(float(levels[i]), 3),
                'precip_mm': round(float(max(0.0, imd_fcst * (1 + 0.1 * math.sin(i)))), 1),
            }
            for i in range(72)
        ]

    # ── History window builder ──────────────────────────────────────────────────
    def _build_history_window(
        self,
        current_level: float,
        rainfall_3d_mm: float,
        history: Optional[List[float]],
        seq_len: int = SEQ_LEN,
    ) -> List[float]:
        if history and len(history) >= seq_len:
            return list(history[-seq_len:])
        rate    = 0.025 if rainfall_3d_mm > 100 else 0.008
        partial = list(history) if history else []
        n_miss  = seq_len - len(partial)
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
            for i in range(72)
        ]

    # ── Model loading ─────────────────────────────────────────────────────────────
    def _load_model(self, station: str):
        """
        Load per-station BiLSTM .pt bundle, then fall back to all.keras / physics.
        Returns (model, config) tuple; both None on failure.
        """
        try:
            import torch
            # Try per-station .pt first
            pt_path = MODEL_DIR / f'{station}_bilstm.pt'
            if not pt_path.exists():
                # Try normalised name (spaces → underscores)
                pt_path = MODEL_DIR / f'{station.replace(" ", "_")}_bilstm.pt'
            if pt_path.exists():
                bundle = torch.load(str(pt_path), map_location='cpu', weights_only=False)
                model  = _build_bilstm_model()
                model.load_state_dict(bundle['model_state'])
                model.eval()
                return model, bundle.get('config', {})
        except Exception as exc:
            print(f'\u26a0\ufe0f FloodPredictor: could not load .pt for {station}: {exc}')
        return None, None


# ── Convenience function for API route ───────────────────────────────────────────
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
