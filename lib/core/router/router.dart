import 'package:flutter/material.dart';
import '../../features/pump_stations/screens/pump_stations_screen.dart';
import '../../features/pump_stations/screens/pump_station_detail_screen.dart';
import '../../features/accessibility/screens/accessibility_screen.dart';

/// Named route constants — single source of truth for navigation
abstract class AppRoutes {
  static const String pumpStations = '/pump-stations';
  static const String pumpStationDetail = '/pump-stations/:id';
  static const String accessibility = '/accessibility';
}

/// Generates routes for Navigator 1.0 (MaterialApp.onGenerateRoute)
Route<dynamic> generateRoute(RouteSettings settings) {
  final name = settings.name ?? '';
  final args = settings.arguments;

  // /pump-stations
  if (name == AppRoutes.pumpStations) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const PumpStationsScreen(),
    );
  }

  // /pump-stations/detail — pass stationId as String argument
  if (name == AppRoutes.pumpStationDetail) {
    final stationId = args is String ? args : '';
    return MaterialPageRoute(
      settings: settings,
      builder: (_) =>
          PumpStationDetailScreen(stationId: stationId),
    );
  }

  // /accessibility
  if (name == AppRoutes.accessibility) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const AccessibilityScreen(),
    );
  }

  // Fallback — 404 screen
  return MaterialPageRoute(
    settings: settings,
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Route "$name" not found',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Helper extension for clean navigation calls
extension AppNavigation on BuildContext {
  Future<T?> pushPumpStations<T>() =>
      Navigator.pushNamed<T>(this, AppRoutes.pumpStations);

  Future<T?> pushPumpStationDetail<T>(String id) =>
      Navigator.pushNamed<T>(this, AppRoutes.pumpStationDetail,
          arguments: id);

  Future<T?> pushAccessibility<T>() =>
      Navigator.pushNamed<T>(this, AppRoutes.accessibility);
}
