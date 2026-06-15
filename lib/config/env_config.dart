// lib/config/env_config.dart
// EnvConfig — Safe runtime configuration.
//
// SECURITY: No secrets are loaded from Flutter assets in production.
// All keys that must remain secret are fetched from the backend proxy.
// The backend (Railway / Render) holds the real keys server-side.
//
// Only NON-SECRET config (base URLs, feature flags, timeouts) lives here.
library;

class EnvConfig {
  EnvConfig._();

  // Base URL for the OpsFlood backend (Railway deployment).
  // This is NOT a secret — it's just an endpoint URL.
  static const String backendBaseUrl =
      String.fromEnvironment('BACKEND_BASE_URL',
          defaultValue: 'https://opsflood-backend.up.railway.app');

  // News API key is proxied via backend — never stored on device.
  // Use GET /api/news instead of calling NewsAPI directly.
  static const bool newsApiProxied = true;

  // Feature flags
  static const bool enableDistrictHeatmap = true;
  static const bool enableMlPredictions   = true;
  static const bool enableAdMob           = true;

  // AdMob IDs — not secrets, but environment-separated
  static const String admobBannerIdAndroid =
      String.fromEnvironment('ADMOB_BANNER_ANDROID',
          defaultValue: 'ca-app-pub-3940256099942544/6300978111'); // test ID

  static const String admobInterstitialIdAndroid =
      String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID',
          defaultValue: 'ca-app-pub-3940256099942544/1033173712'); // test ID

  // Request timeout
  static const Duration httpTimeout = Duration(seconds: 15);

  // Cache TTLs
  static const Duration liveCacheTtl    = Duration(minutes: 5);
  static const Duration forecastCacheTtl = Duration(hours: 1);
}
