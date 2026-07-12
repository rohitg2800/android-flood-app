// lib/config/env_config.dart
// EnvConfig — Safe runtime configuration.
//
// SECURITY: No secrets are loaded from Flutter assets in production.
// All keys that must remain secret are fetched from the backend proxy.
// The backend (Railway / Render) holds the real keys server-side.
//
// Only NON-SECRET config (base URLs, feature flags, timeouts) lives here.
//
// HOW TO PASS PRODUCTION ADMOB IDs AT BUILD TIME:
//   flutter build apk \
//     --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXX/XXXXXXXXXX \
//     --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-XXXX/XXXXXXXXXX \
//     --dart-define=ADMOB_APP_ID_ANDROID=ca-app-pub-XXXX~XXXXXXXXXX
//
// In GitHub Actions, store these as repository secrets and pass via
//   --dart-define=ADMOB_BANNER_ANDROID=${{ secrets.ADMOB_BANNER_ANDROID }}
library;

import 'package:flutter/foundation.dart';
import 'app_config.dart';

class EnvConfig {
  EnvConfig._();

  // Base URL for the OpsFlood backend (Railway deployment).
  // This is NOT a secret — it's just an endpoint URL.
  // Delegates to AppConfig — single source of truth.
  static String get backendBaseUrl => AppConfig.baseUrl;

  // News API key is proxied via backend — never stored on device.
  // Use GET /api/news instead of calling NewsAPI directly.
  static const bool newsApiProxied = true;

  // Feature flags
  static const bool enableDistrictHeatmap = true;
  static const bool enableMlPredictions = true;
  static const bool enableAdMob = true;

  // ──────────────────────────────────────────────────────────────────
  // AdMob IDs — injected at build time via --dart-define.
  // Default values are Google's official test IDs.
  // Production IDs MUST be passed in CI/CD for release builds.
  // ──────────────────────────────────────────────────────────────────

  /// Google official test banner ID (Android).
  static const String _testBannerIdAndroid =
      'ca-app-pub-3940256099942544/6300978111';

  /// Google official test interstitial ID (Android).
  static const String _testInterstitialIdAndroid =
      'ca-app-pub-3940256099942544/1033173712';

  /// Injected production banner ID — falls back to test ID if not set.
  static const String _prodBannerIdAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: '',
  );

  /// Injected production interstitial ID — falls back to test ID if not set.
  static const String _prodInterstitialIdAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: '',
  );

  /// The AdMob App ID — must match AndroidManifest.xml meta-data.
  /// Pass via --dart-define=ADMOB_APP_ID_ANDROID=ca-app-pub-XXXX~XXXXXXXXXX
  static const String admobAppIdAndroid = String.fromEnvironment(
    'ADMOB_APP_ID_ANDROID',
    // Test App ID — must be replaced with real App ID for production.
    defaultValue: 'ca-app-pub-3940256099942544~3347511713',
  );

  /// Returns true if running in a debug build.
  static bool get _isDebug {
    bool d = false;
    assert(() {
      d = true;
      return true;
    }());
    return d;
  }

  /// Active banner ad unit ID.
  /// In debug builds always returns test ID to prevent accidental
  /// test traffic on production AdMob units.
  static String get admobBannerIdAndroid {
    if (_isDebug || _prodBannerIdAndroid.isEmpty) {
      return _testBannerIdAndroid;
    }
    return _prodBannerIdAndroid;
  }

  /// Active interstitial ad unit ID.
  static String get admobInterstitialIdAndroid {
    if (_isDebug || _prodInterstitialIdAndroid.isEmpty) {
      return _testInterstitialIdAndroid;
    }
    return _prodInterstitialIdAndroid;
  }

  /// Whether the current ad IDs are test IDs.
  /// Use this to show a dev warning banner in debug mode.
  static bool get isAdTestMode => admobBannerIdAndroid == _testBannerIdAndroid;

  // Request timeout
  static const Duration httpTimeout = Duration(seconds: 15);

  // Cache TTLs
  static const Duration liveCacheTtl = Duration(minutes: 5);
  static const Duration forecastCacheTtl = Duration(hours: 1);
}
