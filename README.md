<!-- README.md -->
<p align="center">
  <img src="assets/icon/opsflood_icon.png" width="96" alt="OpsFlood icon"/>
</p>

<h1 align="center">OpsFlood</h1>
<p align="center">
  Real-time Bihar flood monitoring &amp; early-warning Android app
  <br/>
  <sub>Built with Flutter 3.22 · Firebase · Riverpod · TFLite · Hive · flutter_map</sub>
</p>

<p align="center">
  <a href="https://github.com/rohitg2800/android-flood-app/actions/workflows/ci.yml">
    <img src="https://github.com/rohitg2800/android-flood-app/actions/workflows/ci.yml/badge.svg" alt="CI"/>
  </a>
  <img src="https://img.shields.io/badge/flutter-3.22.2-blue?logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/dart-3.4-blue?logo=dart" alt="Dart"/>
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License"/>
  <img src="https://img.shields.io/badge/WCAG-2.1%20AA-success" alt="WCAG"/>
</p>

---

## 📍 Overview

OpsFlood is a production-ready Android app that monitors **52 Bihar river gauge stations** in real time, applies on-device ML flood-risk prediction, and delivers critical early warnings to users — even when offline.

### Key Capabilities

| Feature | Detail |
|---|---|
| **Live Gauges** | WebSocket + Firebase polling every 5 min for 52 stations |
| **ML Risk Prediction** | TFLite LSTM model — 24 h & 72 h forecasts, linear fallback |
| **Early Alerts** | FCM push + in-app banners with MODERATE/SEVERE/CRITICAL grading |
| **Watch List** | Per-station bookmarking with instant Home Widget refresh |
| **Offline Mode** | Hive cache + WorkManager background sync; graceful stale-data UI |
| **Sparkline History** | 24 h / 48 h / 72 h level history per station |
| **Multilingual** | English, हिंदी, বাংলা, ଓଡ଼ିଆ (ARB-based l10n) |
| **Accessibility** | WCAG 2.1 AA — high-contrast mode, text scale 1.0–1.4, 48×48 touch targets |
| **3 Visual Themes** | River / Robotic / 3D — switchable at runtime |
| **Interactive Map** | flutter_map with colour-coded risk markers |
| **PDF / CSV Export** | Single-station or bulk report generation |
| **Home Widget** | Android glance widget showing top 3 watched stations |

---

## 🏗️ Architecture

```
lib/
├── data/            # DTO → model mappers, remote data sources
├── models/          # FloodData, AlertModel, FloodPrediction, …
├── repositories/    # FloodRepository (cache + network strategy)
├── services/
│   ├── flood_api_service.dart       # HTTP + XML parsing (CWC RSS)
│   ├── websocket_service.dart       # Real-time WebSocket pipeline
│   ├── local_cache_service.dart     # Hive offline cache
│   ├── alert_engine.dart            # Threshold evaluation + debounce
│   └── ml_service.dart              # TFLite LSTM + linear fallback
├── providers/       # Riverpod StateNotifiers + StreamProviders
├── screens/         # 10 screens (Home, Map, Detail, Settings, …)
├── widgets/         # Reusable — SparklineCard, WatchButton, AccessibleCard, …
├── theme/           # RiverTheme, RoboticTheme, Theme3D, high-contrast colours
├── l10n/            # ARB files + generated Dart classes
├── ml/              # TFLite model asset loader + scaler
└── home_widget/     # Android glance widget

test/
├── widget/          # SparklineCard, WatchButton, SyncStatusBanner
├── unit/            # AccessibilityNotifier, AlertEngine
└── golden/          # MlCard × 5 severity states
```

**State management:** Riverpod 2.x (`StateNotifier`, `StreamProvider`, `FutureProvider`)  
**Navigation:** GoRouter with deep-link support  
**Persistence:** Hive (gauge cache) + SharedPreferences (settings)  
**Background sync:** WorkManager (15-min interval, battery-aware)  

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

# Flood data API (CWC)
CWC_BASE_URL=https://cwc.gov.in/
FLOOD_API_BASE_URL=https://your-backend.com/api

# WebSocket
WS_URL=wss://your-backend.com/ws/gauges

# AdMob (optional)
ADMOB_APP_ID=ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx
ADMOB_BANNER_ID=ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx
```

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

OpsFlood targets **WCAG 2.1 Level AA**:

- High-contrast colour palette (≥4.5:1 body text, ≥3:1 UI elements)
- Text scale: 1.0 × → 1.4 × via `AccessibilitySettingsScreen`
- All interactive elements have ≥ 48×48 dp touch targets
- Colour is never the sole means of conveying risk level (text labels always present)
- Four-language support: English, Hindi, Bengali, Odia

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
4. Add the locale to `accessibilityProvider`’s `setLocale` allowed list

---

## 📦 Key Dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^2.6.1 | State management |
| `firebase_core` / `messaging` | ^3.13.1 / ^15.2.5 | Push notifications |
| `cloud_firestore` | ^5.6.9 | Real-time DB fallback |
| `hive` + `hive_flutter` | ^2.2.3 | Offline gauge cache |
| `flutter_map` + `latlong2` | ^8.1.1 | Interactive river map |
| `fl_chart` | ^0.69.0 | Sparkline history charts |
| `workmanager` | ^0.9.0+3 | Background sync |
| `web_socket_channel` | ^3.0.1 | Real-time WebSocket |
| `flutter_local_notifications` | ^17.2.4 | On-device alerts |
| `home_widget` | ^0.7.0 | Android home screen widget |
| `pdf` + `csv` + `excel` | ^3.10.8 / ^6.0.0 / ^4.0.6 | Export |
| `geolocator` | ^13.0.4 | GPS location |
| `share_plus` | ^10.1.4 | Share reports |

Full list: [`pubspec.yaml`](pubspec.yaml)

---

## 📁 Project Structure (Top Level)

```
android-flood-app/
├── lib/                 # Dart source
├── test/                # Unit / widget / golden tests
├── android/             # Native Android project
├── assets/              # Icons, fonts, splash, station data
├── fastlane/            # Fastfile, Appfile, Pluginfile
├── .github/workflows/   # ci.yml, release.yml
├── pubspec.yaml
├── .env                 # ⚠️ gitignored — never commit
└── README.md
```

---

## 📄 License

MIT © 2026 Rohit Gupta
