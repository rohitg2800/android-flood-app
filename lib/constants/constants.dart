// lib/constants/constants.dart
// Barrel export — import this single file everywhere.
//
// Usage: import '../constants/constants.dart';
//   AppConfig.baseUrl               — env-driven API URL
//   AppConstants.baseUrl            — same value, static alias for legacy files
//   FloodThresholds.critical        — 85.0
//   AlertChannels.criticalId        — 'flood_critical'
//   IndiaGeodata.states             — list of all Indian states
//   IndiaGeodata.monitoredCities    — monitored city metadata

export 'app_config.dart'; // AppConfig  (dotenv-aware)
export 'app_constants.dart'; // AppConstants (static, legacy + new fields)
export 'flood_thresholds.dart'; // FloodThresholds
export 'alert_channels.dart'; // AlertChannels
export 'india_geodata.dart'; // IndiaGeodata
