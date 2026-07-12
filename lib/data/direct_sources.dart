// lib/data/direct_sources.dart
//
// OpsFlood — Direct (No-Backend) API URL Builders (v2)
//
// CORS-safe sources (usable directly from Flutter web + mobile):
//   A) Open-Meteo  — weather forecast (free, no key, 10k req/day)
//   B) GloFAS      — river discharge via flood-api.open-meteo.com
//   C) data.gov.in — reservoir levels (public JSON)
//   D) IMD / SACHET— weather & disaster alerts (public RSS/XML)
//
// CORS-blocked sources (need OpsFlood proxy):
//   E) CWC FFS     — routed via AppConfig.epCwcFfs on OpsFlood backend
library;

import '../config/app_config.dart';

// ═════════════════════════════════════════════════════════════════════════════
// A) Open-Meteo — Weather forecast
// Docs: https://open-meteo.com/en/docs
// Free: 10,000 req/day, no API key required.
// ═════════════════════════════════════════════════════════════════════════════
class OpenMeteoUrls {
  OpenMeteoUrls._();

  static const _base = 'https://api.open-meteo.com/v1';

  /// Current conditions + 48h hourly precipitation, soil moisture & wind.
  static String weather(double lat, double lon) => '$_base/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,relative_humidity_2m,precipitation,rain,'
      'windspeed_10m,winddirection_10m,weathercode,surface_pressure'
      '&hourly=precipitation,precipitation_probability,'
      'soil_moisture_0_1cm,soil_moisture_1_3cm,'
      'windspeed_10m,winddirection_10m'
      '&daily=precipitation_sum,rain_sum,precipitation_hours,'
      'windspeed_10m_max'
      '&forecast_days=3'
      '&past_days=2'
      '&timezone=Asia%2FKolkata';

  /// 7-day hourly precipitation sum (for 7-day rainfall accumulation chart).
  static String precipitation7d(double lat, double lon) => '$_base/forecast'
      '?latitude=$lat&longitude=$lon'
      '&daily=precipitation_sum,rain_sum'
      '&forecast_days=7'
      '&past_days=7'
      '&timezone=Asia%2FKolkata';
}

// ═════════════════════════════════════════════════════════════════════════════
// B) GloFAS — River discharge forecast
// Docs: https://open-meteo.com/en/docs/flood-api
// Same free quota as Open-Meteo. No key required.
// river_discharge         : median ensemble (m³/s) — current live value
// river_discharge_return_period_2/5/20 : statistical thresholds in m³/s
//   2-yr  ≈ "watch" / pre-warning boundary
//   5-yr  ≈ "warning" level
//   20-yr ≈ "danger" level
// These return-period values replace CWC gauge-height thresholds for
// discharge-based alert evaluation, ensuring apples-to-apples comparison.
// ═════════════════════════════════════════════════════════════════════════════
class GloFasUrls {
  GloFasUrls._();

  static const _base = 'https://flood-api.open-meteo.com/v1/flood';

  /// Standard 16-day discharge forecast + 14 days of history.
  /// Use this as the primary river level source.
  static String discharge(double lat, double lon) => '$_base'
      '?latitude=$lat&longitude=$lon'
      '&daily=river_discharge'
      '&forecast_days=16'
      '&past_days=14';

  /// Return-period discharge thresholds for a location.
  /// Returns river_discharge_return_period_2, _5, _20 (all in m³/s).
  /// Call ONCE per city on first poll; cache for the session.
  static String returnPeriods(double lat, double lon) => '$_base'
      '?latitude=$lat&longitude=$lon'
      '&daily=river_discharge_return_period_2,'
      'river_discharge_return_period_5,'
      'river_discharge_return_period_20'
      '&forecast_days=1';

  /// Ensemble spread (min / mean / max) for uncertainty ribbon.
  /// Only call when user opens detailed city view — heavier payload.
  static String dischargeEnsemble(double lat, double lon) => '$_base'
      '?latitude=$lat&longitude=$lon'
      '&daily=river_discharge_mean,river_discharge_max,river_discharge_min'
      '&forecast_days=16'
      '&past_days=14';

  /// Quick 7-day look-ahead for dashboard card sparklines.
  static String discharge7d(double lat, double lon) => '$_base'
      '?latitude=$lat&longitude=$lon'
      '&daily=river_discharge'
      '&forecast_days=7'
      '&past_days=3';
}

// ═════════════════════════════════════════════════════════════════════════════
// C) data.gov.in — Reservoir level dataset (CWC published)
// Dataset: https://data.gov.in/resource/reservoir-levels-central-water-commission
// Public, no auth. Limit=100 returns latest batch.
// ═════════════════════════════════════════════════════════════════════════════
class DataGovUrls {
  DataGovUrls._();

  static const _reservoirResourceId = '3b01bcb8-0b14-4abf-b6f2-c1bfd384ba69';

  /// Latest reservoir levels (all India, most-recent 100 records).
  static String get reservoirLevels =>
      'https://api.data.gov.in/resource/$_reservoirResourceId'
      '?api-version=2.0&format=json&limit=100&offset=0';

  /// Filter reservoir levels by state.
  static String reservoirByState(String state) =>
      'https://api.data.gov.in/resource/$_reservoirResourceId'
      '?api-version=2.0&format=json&limit=50'
      '&filters[state]=${Uri.encodeComponent(state)}';
}

// ═════════════════════════════════════════════════════════════════════════════
// D) IMD / SACHET — Weather & disaster alerts (public feeds)
// No key required. IMD updates every 3–6 h; SACHET is near-real-time.
// ═════════════════════════════════════════════════════════════════════════════
class ImdRssUrls {
  ImdRssUrls._();

  /// SACHET — CAP-format national disaster alerts (near-real-time).
  static const String sachetAlerts =
      'https://sachet.ndma.gov.in/cap_public_website/FeedPage';

  /// IMD — all-India weather bulletins RSS.
  static const String bulletins =
      'https://mausam.imd.gov.in/backend/rss_en.php';

  /// IMD — cyclone track feed (active only during cyclone season).
  static const String cyclone =
      'https://mausam.imd.gov.in/backend/cyclone_rss_en.php';

  /// IMD — heavy rainfall warning RSS.
  static const String heavyRainfall =
      'https://mausam.imd.gov.in/backend/warning_rss_en.php';
}

// ═════════════════════════════════════════════════════════════════════════════
// E) CWC FFS — via OpsFlood proxy (CORS-blocked from browser)
// ═════════════════════════════════════════════════════════════════════════════
class CwcProxyUrls {
  CwcProxyUrls._();

  /// CWC FFS station data via OpsFlood proxy.
  static String station(String code) =>
      '${AppConfig.baseUrl}${AppConfig.epCwcFfs}/$code';

  /// All registered CWC stations.
  static String get stationsRegistry =>
      '${AppConfig.baseUrl}${AppConfig.epCwcStations}';
}

// ═════════════════════════════════════════════════════════════════════════════
// F) OpsFlood ML inference endpoints
// ═════════════════════════════════════════════════════════════════════════════
class OpsFloodUrls {
  OpsFloodUrls._();

  static String get predict => '${AppConfig.baseUrl}${AppConfig.epPredict}';
  static String get health => '${AppConfig.baseUrl}${AppConfig.epHealth}';
  static String get liveTelemetry =>
      '${AppConfig.baseUrl}${AppConfig.epLiveTelemetry}';
  static String get liveLevels =>
      '${AppConfig.baseUrl}${AppConfig.epLiveLevels}';
  static String get criticalAlerts =>
      '${AppConfig.baseUrl}${AppConfig.epCriticalAlerts}';
}
