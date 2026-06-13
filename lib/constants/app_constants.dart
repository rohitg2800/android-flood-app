// lib/constants/app_constants.dart

import 'flood_thresholds.dart';
import 'india_geodata.dart';

class AppConstants {
  AppConstants._();

  // ── Network ───────────────────────────────────────────────────────────────
  static const Duration defaultTimeout       = Duration(seconds: 15);
  static const Duration longTimeout          = Duration(seconds: 30);
  static const Duration shortTimeout         = Duration(seconds: 5);
  static const int      maxRetries           = 3;
  static const Duration retryDelay           = Duration(seconds: 2);

  // ── Cache ─────────────────────────────────────────────────────────────────
  static const Duration cacheTtlShort        = Duration(minutes: 5);
  static const Duration cacheTtlMedium       = Duration(minutes: 15);
  static const Duration cacheTtlLong         = Duration(hours: 1);
  static const Duration cacheTtlVeryLong     = Duration(hours: 6);

  // ── Polling ───────────────────────────────────────────────────────────────
  static const Duration pollIntervalFast     = Duration(minutes: 5);
  static const Duration pollIntervalNormal   = Duration(minutes: 15);
  static const Duration pollIntervalSlow     = Duration(minutes: 30);

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int defaultPageSize           = 20;
  static const int maxPageSize               = 100;

  // ── UI ────────────────────────────────────────────────────────────────────
  static const double cardBorderRadius       = 12.0;
  static const double defaultPadding         = 16.0;
  static const double smallPadding           = 8.0;
  static const double largePadding           = 24.0;
  static const Duration animationFast        = Duration(milliseconds: 200);
  static const Duration animationNormal      = Duration(milliseconds: 350);
  static const Duration animationSlow        = Duration(milliseconds: 600);

  // ── Notification Channels ─────────────────────────────────────────────────
  static const String criticalAlertChannelId   = 'equinox_bh_critical';
  static const String criticalAlertChannelName = 'Critical Flood Alerts';
  static const String warningAlertChannelId    = 'equinox_bh_warning';
  static const String warningAlertChannelName  = 'Flood Warnings';
  static const String infoChannelId            = 'flood_info';
  static const String infoChannelName          = 'Flood Information';

  // ── Severity ──────────────────────────────────────────────────────────────
  static const List<String> severityLevels = [
    'LOW', 'MODERATE', 'SEVERE', 'CRITICAL',
  ];

  // ── Storage Keys ──────────────────────────────────────────────────────────
  static const String storageKeyTheme        = 'theme_mode';
  static const String storageKeyLastSync     = 'last_sync';
  static const String storageKeyAlerts       = 'cached_alerts';
  static const String storageKeyPredictions  = 'cached_predictions';
  static const String storageKeySourcePolicy = 'source_policy';

  // ── Backward-compat shims (used by constants_domain_test) ─────────────────
  /// Delegates to FloodThresholds.critical (capacity % threshold = 90.0).
  static double get criticalThreshold => FloodThresholds.critical;

  /// Delegates to IndiaGeodata.states.
  static List<String> get indianStates => IndiaGeodata.states;
}
