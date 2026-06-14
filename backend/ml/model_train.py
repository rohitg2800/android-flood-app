# backend/ml/model_train.py
# =============================================================================
# OpsFlood  v4.0  —  BiLSTM + Attention Flood Level Training Pipeline (PyTorch)
# =============================================================================
#
# ARCHITECTURE
#   Input  : 24 hourly steps x 11 features
#            level_m, rain_1h, rain_3d, rain_7d, upstream_level,
#            forecast_mm, soil_moisture, discharge_m3s,
#            day_sin, day_cos, hour_sin
#   Output : next 72 hourly gauge levels  (direct multi-step)
#   Model  : BiLSTM(128) -> MultiHeadAttention(4 heads) -> BiLSTM(64)
#            -> Dense(256, gelu) -> Dense(128, gelu) -> Dense(72)
#
# DEVICE    Auto-selects: MPS (Apple M-series) -> CUDA -> CPU
#
# INSTALL
#   pip install torch pandas numpy scikit-learn joblib tqdm matplotlib
#
# USAGE
#   python -m backend.ml.model_train --station all          # train all 34 stations
#   python -m backend.ml.model_train --station Triveni      # single station
#   python -m backend.ml.model_train --station all --plot   # with loss curves
#   python -m backend.ml.model_train --eval  --station Gandhighat
#   python -m backend.ml.model_train --benchmark
# =============================================================================
from __future__ import annotations

import argparse
import json
import math
import os
import platform
import sys
import time
import warnings
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import joblib
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import RobustScaler
from tqdm import tqdm

warnings.filterwarnings('ignore')

# =============================================================================
# PATHS
# =============================================================================
ROOT_DIR   = Path(__file__).parents[2]
DATA_DIR   = ROOT_DIR / 'data'
RAW_DIR    = DATA_DIR / 'raw'
PROC_DIR   = DATA_DIR / 'processed'
MODEL_DIR  = Path(__file__).parent / 'saved_models'
SCALER_DIR = Path(__file__).parent / 'scalers'

for _d in [RAW_DIR, PROC_DIR, MODEL_DIR, SCALER_DIR]:
    _d.mkdir(parents=True, exist_ok=True)

# =============================================================================
# HYPER-PARAMETERS
# =============================================================================
SEQ_LEN    = 24
FORECAST_H = 72
FEATURES = [
    'level_m',
    'rain_1h',
    'rain_3d',
    'rain_7d',
    'upstream_level',
    'forecast_mm',
    'soil_moisture',
    'discharge_m3s',
    'day_sin',
    'day_cos',
    'hour_sin',
]
N_FEATURES = len(FEATURES)

BATCH_SIZE = 64
EPOCHS     = 60
LR         = 3e-4
PATIENCE   = 10      # early stopping patience

# 34 Bihar CWC stations
STATIONS = [
    'Triveni', 'Gandhighat', 'Hathidah', 'Buxar', 'Digha', 'Kursela',
    'Bhagalpur', 'Kahalgaon', 'Munger', 'Sultanganj', 'Barh', 'Mokama',
    'Simaria', 'Barauni', 'Khagaria', 'Rosera', 'Hayaghat', 'Runni_Saidpur',
    'Dheng', 'Lalbegia', 'Muzaffarpur', 'Sonpur', 'Hajipur', 'Doriganj',
    'Gopalganj', 'Siwan', 'Chhapra', 'Revelganj', 'Arrah', 'Koilwar',
    'Patna', 'Fatuha', 'Begusarai', 'Sahibganj',
]

# =============================================================================
# DEVICE
# =============================================================================
def get_device():
    import torch
    if torch.backends.mps.is_available() and torch.backends.mps.is_built():
        return torch.device('mps')
    if torch.cuda.is_available():
        return torch.device('cuda')
    return torch.device('cpu')

# =============================================================================
# DATASET
# =============================================================================
class FloodDataset:
    """Sliding-window dataset. Falls back to synthetic data if no CSV found."""

    def __init__(self, station: str):
        self.station = station
        self.df      = self._load(station)
        self.scaler  = RobustScaler()
        scaled       = self.scaler.fit_transform(self.df[FEATURES].values)
        self.X, self.y = self._make_sequences(scaled)

    def _load(self, station: str) -> pd.DataFrame:
        candidates = [
            RAW_DIR  / f'{station}.csv',
            PROC_DIR / f'{station}.csv',
            RAW_DIR  / f'{station.lower()}.csv',
        ]
        for p in candidates:
            if p.exists():
                df = pd.read_csv(p, parse_dates=['timestamp'])
                df = df.sort_values('timestamp').reset_index(drop=True)
                df = self._ensure_features(df)
                return df
        print(f'  [WARN] No CSV for {station} — using synthetic data')
        return self._synthetic(station)

    @staticmethod
    def _ensure_features(df: pd.DataFrame) -> pd.DataFrame:
        """Add missing feature columns with sensible defaults."""
        if 'timestamp' not in df.columns:
            df['timestamp'] = pd.date_range('2020-01-01', periods=len(df), freq='h')
        ts = pd.to_datetime(df['timestamp'])
        doy = ts.dt.dayofyear
        df['day_sin']  = np.sin(2 * np.pi * doy / 365)
        df['day_cos']  = np.cos(2 * np.pi * doy / 365)
        df['hour_sin'] = np.sin(2 * np.pi * ts.dt.hour / 24)
        for col in FEATURES:
            if col not in df.columns:
                df[col] = 0.0
        df[FEATURES] = df[FEATURES].ffill().fillna(0)
        return df

    @staticmethod
    def _synthetic(station: str) -> pd.DataFrame:
        """Generate plausible monsoon-cycle synthetic data for a station."""
        np.random.seed(abs(hash(station)) % (2**31))
        n    = 8760 * 3   # 3 years of hourly data
        t    = np.arange(n)
        ts   = pd.date_range('2021-06-01', periods=n, freq='h')
        doy  = ts.dayofyear.values
        base = 45 + 20 * np.sin(2 * np.pi * doy / 365 - 1.2)
        noise = np.cumsum(np.random.randn(n) * 0.05)
        level = np.clip(base + noise + np.random.randn(n) * 0.8, 20, 100)
        rain  = np.clip(
            8 * np.sin(2 * np.pi * doy / 365 - 1.0) ** 6 + np.random.exponential(0.5, n),
            0, 120,
        )
        df = pd.DataFrame({
            'timestamp':      ts,
            'level_m':        level,
            'rain_1h':        rain,
            'rain_3d':        pd.Series(rain).rolling(72,  min_periods=1).sum().values,
            'rain_7d':        pd.Series(rain).rolling(168, min_periods=1).sum().values,
            'upstream_level': level + np.random.randn(n) * 1.5,
            'forecast_mm':    np.clip(rain + np.random.randn(n) * 2, 0, 120),
            'soil_moisture':  np.clip(
                0.3 + 0.4 * np.sin(2 * np.pi * doy / 365 - 1.0) + np.random.randn(n) * 0.05,
                0, 1,
            ),
            'discharge_m3s':  np.clip(500 + level * 30 + np.random.randn(n) * 50, 100, 15000),
            'day_sin':        np.sin(2 * np.pi * doy / 365),
            'day_cos':        np.cos(2 * np.pi * doy / 365),
            'hour_sin':       np.sin(2 * np.pi * ts.hour.values / 24),
        })
        return df

    def _make_sequences(self, scaled: np.ndarray):
        X, y = [], []
        total = len(scaled)
        for i in range(total - SEQ_LEN - FORECAST_H + 1):
            X.append(scaled[i : i + SEQ_LEN])
            # target = future level_m values (index 0 = level_m)
            y.append(scaled[i + SEQ_LEN : i + SEQ_LEN + FORECAST_H, 0])
        return np.array(X, dtype=np.float32), np.array(y, dtype=np.float32)

    def split(self, test_size=0.15, val_size=0.15):
        n = len(self.X)
        t = int(n * (1 - test_size - val_size))
        v = int(n * (1 - test_size))
        return (
            (self.X[:t],   self.y[:t]),
            (self.X[t:v],  self.y[t:v]),
            (self.X[v:],   self.y[v:]),
        )

# =============================================================================
# MODEL
# =============================================================================
class BiLSTMAttention(object):
    """Lazy import wrapper so torch is only imported when training starts."""
    pass

def build_model():
    import torch
    import torch.nn as nn

    class _Model(nn.Module):
        def __init__(self):
            super().__init__()
            # BiLSTM layer 1: input 11 -> hidden 128 (x2 directions = 256)
            self.bilstm1 = nn.LSTM(
                input_size=N_FEATURES, hidden_size=128,
                num_layers=1, batch_first=True, bidirectional=True,
            )
            self.drop1 = nn.Dropout(0.25)

            # Multi-head attention over the BiLSTM sequence (dim=256)
            self.attn = nn.MultiheadAttention(
                embed_dim=256, num_heads=4, dropout=0.1, batch_first=True,
            )
            self.norm1 = nn.LayerNorm(256)

            # BiLSTM layer 2: input 256 -> hidden 64 (x2 = 128)
            self.bilstm2 = nn.LSTM(
                input_size=256, hidden_size=64,
                num_layers=1, batch_first=True, bidirectional=True,
            )
            self.drop2 = nn.Dropout(0.2)

            # Dense head
            self.fc1  = nn.Linear(128, 256)
            self.act1 = nn.GELU()
            self.fc2  = nn.Linear(256, 128)
            self.act2 = nn.GELU()
            self.out  = nn.Linear(128, FORECAST_H)

        def forward(self, x):
            # x: (B, SEQ_LEN, N_FEATURES)
            h1, _ = self.bilstm1(x)             # (B, 24, 256)
            h1     = self.drop1(h1)

            a, _  = self.attn(h1, h1, h1)       # (B, 24, 256)
            h1     = self.norm1(h1 + a)          # residual

            h2, _ = self.bilstm2(h1)             # (B, 24, 128)
            h2     = self.drop2(h2)
            h2     = h2[:, -1, :]                # take last time step (B, 128)

            out = self.act1(self.fc1(h2))        # (B, 256)
            out = self.act2(self.fc2(out))        # (B, 128)
            out = self.out(out)                  # (B, 72)
            return out

    return _Model()

# =============================================================================
# TRAINING
# =============================================================================
def train_station(station: str, plot: bool = False) -> Dict:
    import torch
    from torch.utils.data import DataLoader, TensorDataset

    print(f'\n{"="*60}')
    print(f'  Training: {station}')
    print(f'{"="*60}')

    device = get_device()
    print(f'  Device : {device}')

    # Data
    ds = FloodDataset(station)
    (X_tr, y_tr), (X_va, y_va), (X_te, y_te) = ds.split()
    print(f'  Train  : {len(X_tr):,}  Val: {len(X_va):,}  Test: {len(X_te):,}')

    def to_dl(X, y, shuffle=False):
        t = TensorDataset(
            torch.tensor(X, dtype=torch.float32),
            torch.tensor(y, dtype=torch.float32),
        )
        return DataLoader(t, batch_size=BATCH_SIZE, shuffle=shuffle, pin_memory=False)

    tr_dl = to_dl(X_tr, y_tr, shuffle=True)
    va_dl = to_dl(X_va, y_va)
    te_dl = to_dl(X_te, y_te)

    model = build_model().to(device)
    opt   = torch.optim.AdamW(model.parameters(), lr=LR, weight_decay=1e-4)
    sched = torch.optim.lr_scheduler.CosineAnnealingLR(opt, T_max=EPOCHS, eta_min=1e-5)
    loss_fn = torch.nn.HuberLoss(delta=0.5)

    best_val = float('inf')
    patience_ctr = 0
    history = {'train': [], 'val': []}
    best_state = None

    for epoch in range(1, EPOCHS + 1):
        # ── Train
        model.train()
        tr_loss = 0.0
        for xb, yb in tr_dl:
            xb, yb = xb.to(device), yb.to(device)
            opt.zero_grad()
            pred = model(xb)
            loss = loss_fn(pred, yb)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            opt.step()
            tr_loss += loss.item() * len(xb)
        tr_loss /= len(X_tr)

        # ── Validate
        model.eval()
        va_loss = 0.0
        with torch.no_grad():
            for xb, yb in va_dl:
                xb, yb = xb.to(device), yb.to(device)
                pred   = model(xb)
                va_loss += loss_fn(pred, yb).item() * len(xb)
        va_loss /= len(X_va)

        sched.step()
        history['train'].append(tr_loss)
        history['val'].append(va_loss)

        if epoch % 5 == 0 or epoch == 1:
            print(f'  Epoch {epoch:3d}/{EPOCHS}  tr={tr_loss:.4f}  val={va_loss:.4f}')

        # ── Early stopping
        if va_loss < best_val - 1e-5:
            best_val    = va_loss
            patience_ctr = 0
            import copy
            best_state  = copy.deepcopy(model.state_dict())
        else:
            patience_ctr += 1
            if patience_ctr >= PATIENCE:
                print(f'  Early stop at epoch {epoch}')
                break

    # Restore best weights
    if best_state:
        model.load_state_dict(best_state)

    # ── Test evaluation
    model.eval()
    preds, actuals = [], []
    with torch.no_grad():
        for xb, yb in te_dl:
            xb = xb.to(device)
            p  = model(xb).cpu().numpy()
            preds.append(p)
            actuals.append(yb.numpy())
    preds   = np.concatenate(preds)
    actuals = np.concatenate(actuals)

    # Inverse-transform level_m only (column 0)
    def inv(arr):
        dummy = np.zeros((arr.shape[0] * arr.shape[1], N_FEATURES), dtype=np.float32)
        dummy[:, 0] = arr.reshape(-1)
        return ds.scaler.inverse_transform(dummy)[:, 0].reshape(arr.shape)

    p_real = inv(preds)
    a_real = inv(actuals)
    mae    = float(np.mean(np.abs(p_real - a_real)))
    rmse   = float(np.sqrt(np.mean((p_real - a_real) ** 2)))
    print(f'  Test MAE={mae:.3f} m   RMSE={rmse:.3f} m')

    # ── Save model + scaler
    model_path  = MODEL_DIR  / f'{station}_bilstm.pt'
    scaler_path = SCALER_DIR / f'{station}_scaler.joblib'
    torch.save({
        'model_state': model.state_dict(),
        'config': {
            'seq_len': SEQ_LEN, 'forecast_h': FORECAST_H,
            'n_features': N_FEATURES, 'features': FEATURES,
        },
        'metrics': {'mae': mae, 'rmse': rmse},
        'station': station,
    }, model_path)
    joblib.dump(ds.scaler, scaler_path)
    print(f'  Saved  : {model_path.name}  +  {scaler_path.name}')

    # ── Plot
    if plot:
        _plot_training(station, history, p_real, a_real)

    return {'station': station, 'mae': mae, 'rmse': rmse, 'epochs': epoch}

# =============================================================================
# PLOTTING
# =============================================================================
def _plot_training(station, history, preds, actuals):
    try:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt

        fig, axes = plt.subplots(1, 2, figsize=(14, 4))
        fig.suptitle(f'{station}  —  BiLSTM+Attention', fontsize=13, fontweight='bold')

        # Loss curves
        axes[0].plot(history['train'], label='Train', color='#2196F3')
        axes[0].plot(history['val'],   label='Val',   color='#FF5722')
        axes[0].set_title('Huber Loss')
        axes[0].set_xlabel('Epoch')
        axes[0].legend()
        axes[0].grid(alpha=0.3)

        # Prediction vs actual (first 72h)
        axes[1].plot(actuals[0], label='Actual',    color='#4CAF50', linewidth=2)
        axes[1].plot(preds[0],   label='Predicted', color='#FF9800', linestyle='--')
        axes[1].set_title('72h Forecast (first test sample)')
        axes[1].set_xlabel('Hour')
        axes[1].set_ylabel('Level (m)')
        axes[1].legend()
        axes[1].grid(alpha=0.3)

        plt.tight_layout()
        out = MODEL_DIR / f'{station}_training_plot.png'
        plt.savefig(out, dpi=120)
        plt.close()
        print(f'  Plot   : {out.name}')
    except Exception as e:
        print(f'  [WARN] Plot failed: {e}')

# =============================================================================
# BENCHMARK
# =============================================================================
def benchmark():
    import torch
    device = get_device()
    print(f'\nBenchmark device: {device}')
    model = build_model().to(device)
    x     = torch.randn(64, SEQ_LEN, N_FEATURES, device=device)
    # Warm-up
    for _ in range(3):
        _ = model(x)
    t0 = time.perf_counter()
    for _ in range(100):
        _ = model(x)
    dt = (time.perf_counter() - t0) / 100 * 1000
    params = sum(p.numel() for p in model.parameters())
    print(f'  Parameters   : {params:,}')
    print(f'  Inference    : {dt:.2f} ms / batch (batch=64)')
    print(f'  Throughput   : {64 / (dt/1000):.0f} samples/s')

# =============================================================================
# EVALUATE SAVED MODEL
# =============================================================================
def evaluate_station(station: str):
    import torch
    from torch.utils.data import DataLoader, TensorDataset

    model_path  = MODEL_DIR  / f'{station}_bilstm.pt'
    scaler_path = SCALER_DIR / f'{station}_scaler.joblib'
    if not model_path.exists():
        print(f'No saved model for {station}. Run training first.')
        return

    device    = get_device()
    ckpt      = torch.load(model_path, map_location=device)
    model     = build_model().to(device)
    model.load_state_dict(ckpt['model_state'])
    model.eval()
    scaler    = joblib.load(scaler_path)

    ds = FloodDataset(station)
    ds.scaler = scaler
    (_, _), (_, _), (X_te, y_te) = ds.split()

    te_dl = DataLoader(
        TensorDataset(
            torch.tensor(X_te, dtype=torch.float32),
            torch.tensor(y_te, dtype=torch.float32),
        ),
        batch_size=BATCH_SIZE,
    )
    preds, actuals = [], []
    with torch.no_grad():
        for xb, yb in te_dl:
            preds.append(model(xb.to(device)).cpu().numpy())
            actuals.append(yb.numpy())
    preds   = np.concatenate(preds)
    actuals = np.concatenate(actuals)
    mae     = float(np.mean(np.abs(preds - actuals)))
    rmse    = float(np.sqrt(np.mean((preds - actuals)**2)))
    print(f'[{station}] Saved model  MAE={mae:.4f}  RMSE={rmse:.4f}  (scaled)')
    print(f'[{station}] Stored metrics: {ckpt["metrics"]}')

# =============================================================================
# MAIN
# =============================================================================
def main():
    ap = argparse.ArgumentParser(description='OpsFlood BiLSTM Trainer')
    ap.add_argument('--station',   default='Triveni', help='Station name or "all"')
    ap.add_argument('--plot',      action='store_true', help='Save training plots')
    ap.add_argument('--eval',      action='store_true', help='Evaluate saved model')
    ap.add_argument('--benchmark', action='store_true', help='Run inference benchmark')
    args = ap.parse_args()

    print('OpsFlood  v4.0  —  PyTorch BiLSTM+Attention')
    print(f'Python  : {sys.version.split()[0]}')
    print(f'Platform: {platform.platform()}')
    try:
        import torch
        print(f'PyTorch : {torch.__version__}')
        dev = get_device()
        print(f'Device  : {dev}')
    except ImportError:
        print('ERROR: PyTorch not installed.')
        print('Run:  pip install torch pandas numpy scikit-learn joblib tqdm matplotlib')
        sys.exit(1)

    if args.benchmark:
        benchmark()
        return

    if args.eval:
        stations = STATIONS if args.station == 'all' else [args.station]
        for s in stations:
            evaluate_station(s)
        return

    stations = STATIONS if args.station == 'all' else [args.station]
    results  = []
    t_start  = time.time()

    for station in tqdm(stations, desc='Stations', unit='stn'):
        try:
            r = train_station(station, plot=args.plot)
            results.append(r)
        except Exception as e:
            print(f'  [ERROR] {station}: {e}')
            results.append({'station': station, 'error': str(e)})

    elapsed = time.time() - t_start
    print(f'\n{"="*60}')
    print(f'  Done in {elapsed:.1f}s  ({len(results)} stations)')

    ok = [r for r in results if 'mae' in r]
    if ok:
        avg_mae  = np.mean([r['mae']  for r in ok])
        avg_rmse = np.mean([r['rmse'] for r in ok])
        print(f'  Avg MAE  : {avg_mae:.3f} m')
        print(f'  Avg RMSE : {avg_rmse:.3f} m')

    summary_path = MODEL_DIR / 'training_summary.json'
    with open(summary_path, 'w') as f:
        json.dump(results, f, indent=2)
    print(f'  Summary  : {summary_path}')
    print(f'{"="*60}\n')


if __name__ == '__main__':
    main()
