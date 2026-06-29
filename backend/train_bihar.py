"""
train_bihar.py — Train flood prediction model on real Bihar station data.
Uses RandomForestClassifier on 18 Bihar stations with real hourly gauge data.
Output: artifacts/flood_model.pkl + artifacts/feature_columns.pkl
"""
import os, sys, warnings
import numpy as np
import pandas as pd
import joblib
from pathlib import Path
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score

warnings.filterwarnings('ignore')

# ── Bihar station danger levels (from live_engine_bridge_provider.dart) ──────
BIHAR_DANGER_LEVELS = {
    'Patna':        {'warning': 47.50, 'danger': 48.60, 'hfl': 50.52},
    'Gandhighat':   {'warning': 47.50, 'danger': 48.60, 'hfl': 50.52},
    'Dighaghat':    {'warning': 49.30, 'danger': 50.45, 'hfl': 52.52},
    'Birpur':       {'warning': 73.70, 'danger': 76.02, 'hfl': 77.10},
    'Munger':       {'warning': 38.20, 'danger': 39.33, 'hfl': 40.99},
    'Bhagalpur':    {'warning': 32.50, 'danger': 33.68, 'hfl': 34.86},
    'Hajipur':      {'warning': 49.40, 'danger': 50.32, 'hfl': 50.93},
    'Basua':        {'warning': 47.00, 'danger': 48.00, 'hfl': 49.50},
    'Baltara':      {'warning': 32.50, 'danger': 33.85, 'hfl': 36.40},
    'Kursela':      {'warning': 28.00, 'danger': 30.00, 'hfl': 32.10},
    'Jhanjharpur':  {'warning': 48.00, 'danger': 50.00, 'hfl': 53.11},
    'Benibad':      {'warning': 47.00, 'danger': 48.68, 'hfl': 50.12},
    'Samastipur':   {'warning': 44.80, 'danger': 46.00, 'hfl': 49.40},
    'Khagaria':     {'warning': 34.65, 'danger': 35.65, 'hfl': 47.30},
    'Buxar':        {'warning': 59.20, 'danger': 60.30, 'hfl': 62.10},
    'Darauli':      {'warning': 60.50, 'danger': 60.82, 'hfl': 61.82},
    'Dumariaghat':  {'warning': 61.10, 'danger': 62.22, 'hfl': 64.36},
    'Dhengraghat':  {'warning': 35.00, 'danger': 35.65, 'hfl': 38.20},
}

BIHAR_STATIONS = list(BIHAR_DANGER_LEVELS.keys())
DATA_DIR = Path('data/raw')
ARTIFACT_DIR = Path('artifacts')
ARTIFACT_DIR.mkdir(exist_ok=True)

FEATURES = ['level_m', 'rain_1h', 'rain_3d', 'rain_7d',
            'upstream_level', 'forecast_mm', 'soil_moisture',
            'discharge_m3s', 'day_sin', 'day_cos', 'hour_sin',
            'level_pct_danger', 'level_pct_warning', 'rain_intensity']


def label_row(level, thresholds):
    d = thresholds['danger']
    w = thresholds['warning']
    h = thresholds['hfl']
    if level >= h:     return 'CRITICAL'
    if level >= d:     return 'SEVERE'
    if level >= w:     return 'MODERATE'
    return 'LOW'


def load_station(station):
    path = DATA_DIR / f'{station}.csv'
    if not path.exists():
        return None
    df = pd.read_csv(path)
    thresh = BIHAR_DANGER_LEVELS[station]
    
    # Add derived features
    df['level_pct_danger']  = df['level_m'] / thresh['danger']
    df['level_pct_warning'] = df['level_m'] / thresh['warning']
    df['rain_intensity']    = df['rain_1h'] / (df['rain_7d'].clip(lower=0.1))
    
    # Label
    df['label'] = df['level_m'].apply(lambda l: label_row(l, thresh))
    
    return df


def main():
    print('=' * 60)
    print('Bihar Flood Model Training — Real Station Data')
    print('=' * 60)
    
    all_dfs = []
    for station in BIHAR_STATIONS:
        df = load_station(station)
        if df is not None:
            df['station'] = station
            all_dfs.append(df)
            counts = df['label'].value_counts().to_dict()
            print(f'  {station:20s}: {len(df):6d} rows  {counts}')
    
    combined = pd.concat(all_dfs, ignore_index=True)
    print(f'\nTotal rows: {len(combined):,}')
    print(f'Label distribution:\n{combined["label"].value_counts()}')
    
    # Features + labels
    available = [f for f in FEATURES if f in combined.columns]
    X = combined[available].fillna(0).values
    y = combined['label'].values
    
    # Train/test split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y)
    
    # Scale
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_test  = scaler.transform(X_test)
    
    print('\nTraining RandomForest on Bihar data...')
    model = RandomForestClassifier(
        n_estimators=200,
        max_depth=12,
        min_samples_leaf=5,
        class_weight='balanced',
        random_state=42,
        n_jobs=-1,
    )
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    print(f'\nAccuracy: {acc:.4f}')
    print(classification_report(y_test, y_pred))
    
    # Save
    joblib.dump(model,  ARTIFACT_DIR / 'flood_model.pkl')
    joblib.dump(scaler, ARTIFACT_DIR / 'flood_scaler.pkl')
    joblib.dump(available, ARTIFACT_DIR / 'feature_columns.pkl')
    
    print(f'\nSaved to {ARTIFACT_DIR}/')
    print('  flood_model.pkl')
    print('  flood_scaler.pkl')
    print('  feature_columns.pkl')
    print('\nBihar model training complete!')


if __name__ == '__main__':
    main()
