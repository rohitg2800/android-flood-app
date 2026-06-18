// lib/screens/dashboard_screen.dart  v10.3  (18 Jun 2026)
//
// v10.3:
//   • _riskForecastStrip now reads filteredBulkPredictionsProvider
//     so the Risk Forecast Strip respects the pre-monsoon baseline filter.
//     Previously it used biharBulkPredictionsProvider directly and would
//     show sub-threshold noise during pre-monsoon / low-water periods.
library;

import 'package:flutter/material.dart';
import '../widgets/app_icon_box.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../providers/bihar_live_provider.dart';
import '../providers/real_time_river_provider.dart';
import '../models/river_station.dart';
import '../providers/alerts_badge_provider.dart';
import '../widgets/summary_strip.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

// ── screen imports ────────────────────────────────────────────────────────────
import 'ai_prediction_screen.dart';
import 'river_monitor_screen.dart';
import 'live_stations_screen.dart';
import 'bihar_river_map_screen.dart';
import 'rainfall_forecast_screen.dart';
import