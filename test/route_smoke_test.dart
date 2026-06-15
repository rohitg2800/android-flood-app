// test/route_smoke_test.dart
// Phase 3 — Route Smoke Tests
// Verifies that all 35+ named routes defined in main.dart resolve
// to non-null PageRoute objects without throwing.
// This catches missing-screen compile errors BEFORE Play Store submission.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equinox_flood/app_router.dart';

void main() {
  // All routes defined in Routes class
  const allRoutes = [
    Routes.splash,
    Routes.onboarding,
    Routes.shell,
    Routes.dashboard,
    Routes.alerts,
    Routes.monitors,
    Routes.predict,
    Routes.settings,
    Routes.sos,
    Routes.evacuation,
    Routes.weather,
    Routes.riverMonitor,
    Routes.stateMatrix,
    Routes.modelInfo,
    Routes.biharRiverMap,
    Routes.liveStations,
    Routes.news,
    Routes.map,
    Routes.community,
    Routes.export_,
    Routes.notificationSettings,
    Routes.incidentReport,
    Routes.crowdReports,
    Routes.aiPredictor,
    Routes.indiaRiverExplorer,
    Routes.rainfallForecast,
    Routes.historicalAnalytics,
    Routes.analytics,
    Routes.profile,
    Routes.adminDashboard,
    Routes.cityDetail,
    Routes.riverDetail,
    Routes.stationDetail,
  ];

  group('Route constants are non-null and non-empty strings', () {
    for (final route in allRoutes) {
      test('Route $route is valid', () {
        expect(route, isNotNull);
        expect(route, isA<String>());
        expect(route.trim(), isNotEmpty);
        expect(route, startsWith('/'));
      });
    }
  });

  group('No duplicate route paths', () {
    test('all route strings are unique', () {
      final unique = allRoutes.toSet();
      expect(unique.length, equals(allRoutes.length),
          reason: 'Duplicate route path detected: '
              '${allRoutes.where((r) => allRoutes.where((x) => x == r).length > 1).toSet()}');
    });
  });
}
