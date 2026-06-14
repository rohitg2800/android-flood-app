# backend/ml/model_train.py
# =============================================================================
# OpsFlood  v3.0  —  BiLSTM + Attention Flood Level Training Pipeline
# =============================================================================
#
# ARCHITECTURE
#   Input  : 24 hourly steps × 11 features
#            gauge_level, rain_1h, rain_3d, rain_7d, upstream_level,
#            imd_forecast_mm, soil_moisture_idx, discharge_m3s,
#            day_sin, day_cos, hour_sin, hour_cos
#   Output : next 72 hourly gauge levels  (direct multi-step)
#   Model  : BiLSTM(128) → MultiHead-Attention(4 heads) → BiLSTM(64)
#            → Dense(256, gelu) → Dense(128, gelu) → Dense(72)
#
# BACKEND   Auto-selects: TensorFlow (Linux/Windows) → PyTorch (Mac M-series)
#
# DATA SOURCES
#   CWC daily gauge bulletins  — https://www.india-water.gov.in
#   IMD GridPoint Rainfall     — https://imdpune.gov.in
#   Bihar WRD bulletins        — https://www.fmiscwrdbihar.gov.in
#   CWC CWPRS thresholds 2025  — https://cwc.gov.in
#
# INSTALL (Mac M-series)
#   pip install torch pandas numpy scikit-learn joblib tqdm matplotlib
#
# INSTALL (Linux / Windows)
#   pip install tensorflow pandas numpy scikit-learn joblib tqdm matplotlib
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
SEQ_LEN    = 24       # 24-hour look-back window (1h resolution)
FORECAST_H = 72       # 72-hour direct multi-step forecast
FEATURES   = [
    'level_m',          # gauge reading (m MSL)
    'rain_1h',          # hourly rainfall (mm)
    'rain_3d',          # 3-day accumulated rainfall (mm)
    'rain_7d',          # 7-day accumulated rainfall (mm)
    'upstream_level',   # nearest upstream gauge (m MSL)
    'forecast_mm',      # IMD 24h rainfall forecast (mm)
    'soil_moisture',    # dimensionless 0–1 soil saturation index
    'discharge_m3s',    # river discharge (m³/s), zero when un