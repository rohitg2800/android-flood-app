"""
backend/ml/bootstrap_model.py — OpsFlood Model Bootstrap (Priority 2)

Purpose:
    Auto-generates a CWC-calibrated synthetic training dataset and trains an
    XGBoost classifier when no saved model artifact exists in saved_models/.
    Called at Railway startup from app.py lifespan if saved_models/ is empty.

Outputs:
    backend/ml/saved_models/flood_model.pkl   — trained XGBoost classifier
    backend/ml/scalers/scaler.pkl             — fitted StandardScaler
    backend/ml/saved_models/bootstrap_meta.json — training metadata

Usage:
    from backend.ml.bootstrap_model import ensure_model_exists
    ensure_model_exists()   # no-op if model already present
"""

from __future__ import annotations

import json
import pickle
import time
from pathlib import Path
from typing import Tuple

import numpy as np

# ── Paths ────────────────────────────────────────────────────────────────────
_BASE      = Path(__file__).parent
MODEL_DIR  = _BASE / "saved_models"
SCALER_DIR = _BASE / "scalers"
MODEL_PATH = MODEL_DIR / "flood_model.pkl"
SCALER_PATH = SCALER_DIR / "scaler.pkl"
META_PATH  = MODEL_DIR / "bootstrap_meta.json"

# ── Bihar-calibrated CWC thresholds (mirrors flood_engine.dart v1.3) ─────────
_BIHAR = {
    "moderate": 11.0,
    "severe":   12.0,
    "critical": 13.2,
    "danger":   12.0,
    "warning":  11.0,
    "rain_mod": 200.0,
    "rain_sev": 350.0,
    "rain_crit":500.0,
}

N_SAMPLES  = 4000
RANDOM_SEED = 42


def _generate_dataset() -> Tuple[np.ndarray, np.ndarray]:
    """Synthetic CWC-Bihar-calibrated dataset: 11 features → 4-class label."""
    rng = np.random.default_rng(RANDOM_SEED)

    # Feature columns (match FloodInput.toFeatureVector order):
    # [peak_m, duration_days, time_to_peak_days, recession_days,
    #  t1d..t7d rainfall (7 features)]

    # LOW: peak < 11.0, rainfall < 200
    n_low = N_SAMPLES // 4
    low = np.column_stack([
        rng.uniform(4.0, 10.9,  n_low),   # peak
        rng.uniform(1.0, 5.0,   n_low),   # duration
        rng.uniform(0.5, 3.0,   n_low),   # time_to_peak
        rng.uniform(1.0, 4.0,   n_low),   # recession
        *[rng.uniform(0, 28.0, n_low) for _ in range(7)],  # t1d–t7d
    ])

    # MODERATE: peak 11.0–11.9, rainfall 200–349
    n_mod = N_SAMPLES // 4
    mod = np.column_stack([
        rng.uniform(11.0, 11.9, n_mod),
        rng.uniform(3.0, 8.0,  n_mod),
        rng.uniform(1.0, 4.0,  n_mod),
        rng.uniform(2.0, 6.0,  n_mod),
        *[rng.uniform(25, 50.0, n_mod) for _ in range(7)],
    ])

    # SEVERE: peak 12.0–13.1, rainfall 350–499
    n_sev = N_SAMPLES // 4
    sev = np.column_stack([
        rng.uniform(12.0, 13.1, n_sev),
        rng.uniform(5.0, 12.0, n_sev),
        rng.uniform(0.5, 2.5,  n_sev),
        rng.uniform(3.0, 8.0,  n_sev),
        *[rng.uniform(45, 72.0, n_sev) for _ in range(7)],
    ])

    # CRITICAL: peak >= 13.2, rainfall >= 500
    n_crit = N_SAMPLES - n_low - n_mod - n_sev
    crit = np.column_stack([
        rng.uniform(13.2, 16.0, n_crit),
        rng.uniform(7.0, 20.0,  n_crit),
        rng.uniform(0.2, 1.5,   n_crit),
        rng.uniform(5.0, 14.0,  n_crit),
        *[rng.uniform(65, 100.0, n_crit) for _ in range(7)],
    ])

    X = np.vstack([low, mod, sev, crit])
    y = np.array(
        [0] * n_low + [1] * n_mod + [2] * n_sev + [3] * n_crit,
        dtype=np.int32,
    )
    # Shuffle
    idx = rng.permutation(len(y))
    return X[idx], y[idx]


def bootstrap() -> None:
    """Train and persist the bootstrap model + scaler."""
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    SCALER_DIR.mkdir(parents=True, exist_ok=True)

    print("[Bootstrap] Generating synthetic CWC-Bihar training data...")
    X, y = _generate_dataset()

    split = int(0.8 * len(X))
    X_train, X_test = X[:split], X[split:]
    y_train, y_test = y[:split], y[split:]

    from sklearn.preprocessing import StandardScaler

    scaler = StandardScaler()
    X_train_s = scaler.fit_transform(X_train)
    X_test_s  = scaler.transform(X_test)

    try:
        from xgboost import XGBClassifier
        model = XGBClassifier(
            n_estimators=200,
            max_depth=6,
            learning_rate=0.1,
            use_label_encoder=False,
            eval_metric="mlogloss",
            random_state=RANDOM_SEED,
        )
    except ImportError:
        from sklearn.ensemble import RandomForestClassifier
        print("[Bootstrap] XGBoost not available — using RandomForest fallback.")
        model = RandomForestClassifier(n_estimators=200, random_state=RANDOM_SEED)

    print("[Bootstrap] Training...")
    t0 = time.time()
    model.fit(X_train_s, y_train)
    elapsed = round(time.time() - t0, 2)

    from sklearn.metrics import accuracy_score, f1_score
    y_pred = model.predict(X_test_s)
    acc    = round(accuracy_score(y_test, y_pred), 4)
    wf1    = round(f1_score(y_test, y_pred, average="weighted"), 4)

    with open(MODEL_PATH, "wb") as f:
        pickle.dump(model, f)
    with open(SCALER_PATH, "wb") as f:
        pickle.dump(scaler, f)

    meta = {
        "source": "bootstrap_synthetic_cwc_bihar_v1",
        "n_train": len(X_train),
        "n_test":  len(X_test),
        "accuracy": acc,
        "weighted_f1": wf1,
        "train_time_s": elapsed,
        "model_type": type(model).__name__,
        "features": [
            "peak_flood_level_m", "event_duration_days", "time_to_peak_days",
            "recession_time_days", "t1d", "t2d", "t3d", "t4d", "t5d", "t6d", "t7d",
        ],
        "class_map": {"0": "LOW", "1": "MODERATE", "2": "SEVERE", "3": "CRITICAL"},
    }
    with open(META_PATH, "w") as f:
        json.dump(meta, f, indent=2)

    print(
        f"[Bootstrap] Done in {elapsed}s — accuracy={acc*100:.1f}%  weighted_f1={wf1:.4f}"
    )
    print(f"[Bootstrap] Model saved → {MODEL_PATH}")
    print(f"[Bootstrap] Scaler saved → {SCALER_PATH}")


def ensure_model_exists() -> None:
    """Call this at startup. Runs bootstrap() only if model is missing."""
    if MODEL_PATH.exists() and SCALER_PATH.exists():
        print(f"[Bootstrap] Model artifact found at {MODEL_PATH} — skipping bootstrap.")
        return
    print("[Bootstrap] No saved model found — running bootstrap training...")
    bootstrap()
