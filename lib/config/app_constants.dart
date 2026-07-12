import 'app_config.dart';

class AppConstants {
  // ── Flood level defaults ──────────────────────────────────────────────────
  static const double defaultWarningLevel = 8.0;
  static const double defaultDangerLevel = 10.0;

  // ── Monitored cities ─────────────────────────────────────────────────────
  static const List<String> monitoredCities = [
    'Patna',
    'Varanasi',
    'Allahabad',
    'Lucknow',
    'Gorakhpur',
    'Gaya',
    'Bhagalpur',
    'Munger',
  ];

  // ── Base URL — single source of truth: delegates to AppConfig ─────────────
  @Deprecated("Use AppConfig.baseUrl directly")
  static String get baseUrl => AppConfig.baseUrl;

  // ── HTTP client defaults ──────────────────────────────────────────────────
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration shortTimeout = Duration(seconds: 10);
  static const Duration retryDelay = Duration(seconds: 2);
  static const int maxRetries = 3;
}
