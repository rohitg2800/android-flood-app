<!-- README.md -->
<p align="center">
  <img src="assets/icon/opsflood_icon.png" width="96" alt="EQUINOX-BR05 icon"/>
</p>

<h1 align="center">EQUINOX‑BR05 (OpsFlood)</h1>
<p align="center">
  AI flood prediction & live river monitoring for India — open-source Flutter app + FastAPI backend + Firebase
  <br/>
  <sub>Built with Flutter 3.22 · Dart 3.4 · FastAPI · Firebase · Riverpod · flutter_map · Hive</sub>
</p>

<p align="center">
  <a href="https://github.com/rohitg2800/android-flood-app/actions/workflows/ci.yml">
    <img src="https://github.com/rohitg2800/android-flood-app/actions/workflows/ci.yml/badge.svg" alt="CI"/>
  </a>
  <img src="https://img.shields.io/badge/flutter-3.22.2-blue?logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/dart-3.4-blue?logo=dart" alt="Dart"/>
  <img src="https://img.shields.io/badge/backend-FastAPI-brightgreen" alt="FastAPI"/>
  <img src="https://img.shields.io/badge/firebase-enabled-orange?logo=firebase" alt="Firebase"/>
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License"/>
  <img src="https://img.shields.io/badge/WCAG-2.1%20AA-success" alt="WCAG"/>
</p>

---

## 📍 What is EQUINOX‑BR05?

EQUINOX‑BR05 (android-flood-app) is an open, India‑first flood intelligence platform: a multi‑platform Flutter app + co‑located FastAPI/ML backend + Firebase, wired to real river and station data.

It started as a **real‑time Bihar flood monitoring & early‑warning Android app**, and has evolved into a full stack that you can deploy, extend and study end‑to‑end — from data scraping and ML models to mobile UX and push alerts.

> **Goal:** put trustworthy, hyperlocal flood risk in the hands of people in Bihar and across India — even on low‑end Android devices with flaky connectivity.

---

## 🌊 Key user‑facing capabilities

OpsFlood is a production‑ready Android app that monitors Bihar/India river gauge stations in real time, applies ML flood‑risk prediction, and delivers critical early warnings — even when offline.

| Capability | What the user gets |
|---|---|
| **Live river gauges** | Real‑time water level trends for dozens of Bihar/India stations, updated via HTTP/WebSocket + Firebase where available. |
| **ML‑based flood risk** | Model‑driven risk score per station (e.g. SAFE / WATCH / WARNING / DANGER) from historical patterns and recent levels. |
| **Early alerts** | FCM push + in‑app banners with MODERATE/SEVERE/CRITICAL grading when risk crosses thresholds. |
| **Watch list** | Per‑station bookmarking with instant home‑widget refresh. |
| **Offline mode** | Hive cache + WorkManager background sync; app stays usable with clear stale‑data UI when network is down. |
| **Sparkline history** | 24h / 48h / 72h level history per station. |
| **Interactive map** | `flutter_map` with colour‑coded risk markers and detail sheets. |
| **Accessibility** | WCAG 2.1 AA target — high contrast, text scale 1.0–1.4, ≥48×48 dp touch targets. |
| **Localization** | English, हिंदी, বাংলা, ଓଡ଼ିଆ using ARB‑based l10n. |

---

## 🧱 System overview (frontend + backend)

This repo is a **mono‑repo** that contains both the Flutter app and the FastAPI backend.

- **Frontend (Flutter)**
  - Lives under `lib/`, `assets/`, `test/`, platform folders (`android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`).
  - Uses Riverpod 2.x for state management (`providers/`), layered repositories (`repositories/`) on top of services (`services/`), and typed models (`models/`).
  - Features background sync via WorkManager, offline persistence via Hive, interactive maps via `flutter_map`, and a home widget via `home_widget/`.

- **Backend (FastAPI + ML)**
  - Lives in `backend/` and is a full FastAPI app with:
    - **Data ingestion** from Central Water Commission, WRD Bihar and GloFAS via dedicated scrapers (`cwc_scraper.py`, `wrd_bihar_scraper.py`, `glofas_fetcher.py`) and a `data_pipeline.py` orchestrator.
    - **Caching & storage** through `glofas_cache.py` and `postgres_store.py` (for historical series and model inputs/outputs).
    - **ML models** trained via `train.py`, `train_xgboost.py`, `train_indofloods.py`, with metrics in `model_metrics.py` and artifact versioning in `verify_model_artifact_version.py`.
    - **Risk grading logic** encoded per‑state in `state_severity_matrix.py` so different basins can have different thresholds.
    - **APIs & WebSockets** exposed through `app.py`, `routers/`, and `ws_server.py` to feed the app real‑time data and risk scores.
    - **Alert channels** such as Twilio SMS (`twilio_sms.py`) that can complement FCM for non‑smartphone users.

Deployments are configured via `render.yaml` / `railway.toml` at the repo root, with backend package requirements captured in `backend/requirements.txt` and root‑level `requirements.txt`.

---

## 🛡️ Defensive design & failure handling

This project intentionally takes a **defensive** approach so that bad networks, bad data, or backend failures degrade gracefully instead of breaking the app.

### Network & backend failures

- **Offline‑first UX**
  - All critical station data is cached in Hive. If the network is down, the app shows the last known values with a clear "stale" indicator instead of crashing or hiding data.
- **Backend downtime / high latency**
  - The app does not block on a single slow API: it uses repository‑layer timeouts and keeps previously cached values visible while retrying in the background.
  - WebSocket disconnects are handled with exponential back‑off reconnects and fall back to periodic HTTP polling when necessary.

### Data quality & ML robustness

- **Input validation & parsing**
  - Backend scrapers validate and normalize upstream HTML/XML/CSV before exposing gauges to the app, so UI never sees half‑parsed junk.
- **State‑specific thresholds**
  - Severity thresholds live in `state_severity_matrix.py`, so you can tune risk grading per‑state (e.g. Bihar vs Odisha) without touching ML weights.
- **Model fallbacks**
  - The app and backend both support fallbacks (e.g. linear / rules‑based) when ML predictions are missing or a model artifact fails verification.
  - `verify_model_artifact_version.py` is used to ensure the deployed model matches the expected schema and training metadata before going live.

### Security & privacy

- **Secrets & config**
  - Sensitive values go into `.env` and environment variables — not into Git. `firebase.json`, `firestore.rules`, and `SECURITY.md` document the security posture.
- **Firestore rules**
  - Firestore is used in a locked‑down way: only specific collections are readable by the app, and writes are restricted to what the app actually needs.
- **User data**
  - The app does not require login for basic usage; minimal user data is collected (e.g. device tokens for FCM).
- **CI checks**
  - GitHub Actions run format, analyze, tests and golden tests on every push to `main`, with a coverage gate ≥ 60% to catch regressions early.

### Known limitations (by design)

- Forecast skill ultimately depends on the quality & latency of upstream data providers (CWC, WRD Bihar, GloFAS, etc.).
- The app is optimized for Android first; other Flutter platforms are scaffolded but not as battle‑tested.
- ML models are focused on riverine flooding; urban pluvial flooding (drainage, local rainfall) is not yet fully modelled.

These constraints are called out explicitly so that governments, NGOs and researchers can understand how to extend or adapt the system safely.

---

## 🏗️ Frontend architecture

```text
lib/
├── ads/             # AdMob integration and abstractions
├── config/          # Environment & runtime config
├── constants/       # Global constants and enums
├── data/            # DTO → model mappers, local JSON, static data
├── models/          # FloodData, Station, FloodPrediction, Severity, …
├── repositories/    # FloodRepository (cache + network), SettingsRepository, …
├── services/
│   ├── flood_api_service.dart       # HTTP client for backend flood APIs
│   ├── websocket_service.dart       # Real-time WebSocket pipeline
│   ├── local_cache_service.dart     # Hive offline cache
│   ├── alert_engine.dart            # Threshold evaluation + debounce
│   ├── ml_service.dart              # On-device / remote ML inference
│   └── firebase_service.dart        # FCM, Firestore hooks
├── providers/       # Riverpod Notifiers / AsyncProviders / global app state
├── screens/         # Home, Map, StationDetail, Settings, About, …
├── widgets/         # SparklineCard, WatchButton, AccessibleCard, …
├── theme/           # RiverTheme, RoboticTheme, 3D theme, high-contrast colors
├── l10n/            # ARB files + generated localization classes
├── ml/              # ML input builders, scaling, (de)serialization
├── home_widget/     # Android home screen widget interop
├── extensions/      # Extension methods for DateTime, num, Iterable, …
├── mixins/          # Shared mixins for common widget behaviors
└── utils/           # Logging, formatting, error helpers

test/
├── widget/          # Widget tests (SparklineCard, WatchButton, etc.)
├── unit/            # Pure Dart units (AlertEngine, Notifiers, utils)
└── golden/          # Golden tests (critical widgets × severity states)
```

**State management:** Riverpod 2.x (`StateNotifier`, `AsyncNotifier`, `StreamProvider`, `FutureProvider`)  
**Navigation:** GoRouter with deep‑link support  
**Persistence:** Hive (gauge cache) + SharedPreferences (settings)  
**Background sync:** WorkManager (15‑min interval, battery‑aware)  

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version |
|---|---|
| Flutter | 3.22.2 |
| Dart | 3.4+ |
| Android Studio / VS Code | latest |
| Java | 17 (for Gradle) |

### 1. Clone & install

```bash
git clone https://github.com/rohitg2800/android-flood-app.git
cd android-flood-app
flutter pub get
```

### 2. Environment variables

Create `.env` in the repo root (never commit this):

```dotenv
# Firebase
FIREBASE_PROJECT_ID=your-project-id

# Flood data API (FastAPI backend)
FLOOD_API_BASE_URL=https://your-backend.com/api

# WebSocket
WS_URL=wss://your-backend.com/ws/gauges

# Optional: AdMob
ADMOB_APP_ID=ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx
ADMOB_BANNER_ID=ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx
```

Backend‑specific environment variables (database connection, Twilio keys, etc.) are configured on the server (Railway/Render) and documented in `backend/REFACTORING.md` / `backend/TODO.md`.

### 3. Firebase setup

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure (generates google-services.json + firebase_options.dart)
flutterfire configure --project=your-project-id
```

### 4. Generate code

```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
```

### 5. Run

```bash
flutter run                  # debug on connected device
flutter run --release        # release mode
```

---

## 🧪 Testing

```bash
# Unit + widget tests
flutter test

# With coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Golden tests (first time — generates reference PNGs)
flutter test --update-goldens test/golden/

# Golden tests (CI — pixel compare)
flutter test --tags golden test/golden/

# Lint
flutter analyze --fatal-infos
dart format --set-exit-if-changed lib/ test/
```

**Coverage gate:** CI enforces ≥ 60% line coverage.

---

## 🔧 CI / CD

| Workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` | PR + push to `main` | Format → Analyze → Unit/Widget tests (60% gate) → Golden tests |
| `release.yml` | Push `v*` tag | Signed APK + AAB build → GitHub Release |
| Fastlane `internal` | Manual / CI | AAB → Play Store Internal track |
| Fastlane `beta` | Manual | Internal → Open Beta promotion |
| Fastlane `production` | Manual | Beta → Production (configurable rollout %) |

### Release a new version

```bash
git tag v1.3.0
git push origin v1.3.0
# → release.yml fires automatically
# → Then: bundle exec fastlane internal
```

### Required GitHub Secrets

| Secret | Purpose |
|---|---|
| `KEYSTORE_BASE64` | base64-encoded release keystore |
| `KEYSTORE_PASSWORD` | keystore password |
| `KEY_ALIAS` | key alias |
| `KEY_PASSWORD` | key password |
| `SUPPLY_JSON_KEY_DATA` | Play Store service-account JSON |
| `CODECOV_TOKEN` | Coverage upload |

---

## ♿ Accessibility

EQUINOX‑BR05 targets **WCAG 2.1 Level AA**:

- High‑contrast colour palette (≥4.5:1 body text, ≥3:1 UI elements)
- Text scale: 1.0× → 1.4× via `AccessibilitySettingsScreen`
- All interactive elements have ≥ 48×48 dp touch targets
- Colour is never the sole means of conveying risk level (text labels always present)
- Four‑language support: English, Hindi, Bengali, Odia

---

## 🗣️ Localization

ARB source files live in `lib/l10n/`.

| Locale | File |
|---|---|
| English | `app_en.arb` |
| Hindi | `app_hi.arb` |
| Bengali | `app_bn.arb` |
| Odia | `app_or.arb` |

To add a new language:
1. Copy `app_en.arb` → `app_xx.arb`
2. Translate all values
3. Run `flutter gen-l10n`
4. Add the locale to the allowed list in your locale provider

---

## 📦 Key dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^2.6.1 | State management |
| `firebase_core` / `messaging` | ^3.13.1 / ^15.2.5 | Push notifications |
| `cloud_firestore` | ^5.6.9 | Real‑time DB fallback |
| `hive` + `hive_flutter` | ^2.2.3 | Offline gauge cache |
| `flutter_map` + `latlong2` | ^8.1.1 | Interactive river map |
| `fl_chart` | ^0.69.0 | Sparkline history charts |
| `workmanager` | ^0.9.0+3 | Background sync |
| `web_socket_channel` | ^3.0.1 | Real‑time WebSocket |
| `flutter_local_notifications` | ^17.2.4 | On‑device alerts |
| `home_widget` | ^0.7.0 | Android home screen widget |
| `pdf` + `csv` + `excel` | ^3.10.8 / ^6.0.0 / ^4.0.6 | Export |
| `geolocator` | ^13.0.4 | GPS location |
| `share_plus` | ^10.1.4 | Share reports |

Full list: [`pubspec.yaml`](pubspec.yaml)

---

## 📁 Project structure (top level)

```text
android-flood-app/
├── lib/                 # Dart source
├── test/                # Unit / widget / golden tests
├── backend/             # FastAPI app, ML, scrapers, pipelines
├── android/             # Native Android project
├── assets/              # Icons, fonts, splash, station data
├── fastlane/            # Fastfile, Appfile, Pluginfile
├── .github/workflows/   # ci.yml, release.yml
├── pubspec.yaml
├── requirements.txt     # Root backend/runtime requirements
├── railway.toml         # Railway deployment config
├── render.yaml          # Render deployment config
├── .env                 # ⚠️ gitignored — never commit
└── README.md
```

---

## 📄 License

MIT © 2026 Rohit Raj
