import 'package:flutter/material.dart';

import '../services/real_time_service.dart';
import '../screens/india_river_explorer_screen.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'monitors_screen.dart';
import 'predict_screen.dart';
import 'river_monitor_screen.dart';
import 'weather_screen.dart';
// In any screen, replace mock data with:
import '../services/cwc_live_provider.dart';

final reading = await CwcLiveProvider.instance.getReadingFromMap(
  AppConstants.monitoredCities.firstWhere((m) => m['city'] == 'Patna')
);

print(reading.currentLevelM);  // Real CWC gauge reading
print(reading.riskLabel);      // CRITICAL / SEVERE / MODERATE / LOW
print(reading.alertColour);    // RED / ORANGE / YELLOW / GREEN
print(reading.source);         // Which source provided it

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // FIX 1: Only HomeScreen starts/stops polling. Individual screens must NOT
  // call startPolling() themselves — that caused duplicate listeners + full
  // rebuilds across all 7 screens on every poll tick.
  final RealTimeService _svc = RealTimeService();
  int _currentIndex = 0;

  // FIX 2: Replace IndexedStack (keeps all 7 alive) with a lazy builder that
  // only mounts the active screen. Off-screen widgets are fully unmounted,
  // so they cannot receive notifyListeners() calls.
  static const _destinations = [
    _NavEntry(label: 'Home',       icon: Icons.dashboard_outlined,       selectedIcon: Icons.dashboard),
    _NavEntry(label: 'Monitors',   icon: Icons.monitor_heart_outlined,   selectedIcon: Icons.monitor_heart),
    _NavEntry(label: 'Alerts',     icon: Icons.notifications_outlined,   selectedIcon: Icons.notifications),
    _NavEntry(label: 'Weather',    icon: Icons.cloud_outlined,           selectedIcon: Icons.cloud),
    _NavEntry(label: 'Predict',    icon: Icons.model_training_outlined,  selectedIcon: Icons.model_training),
    _NavEntry(label: 'Rivers',     icon: Icons.water_outlined,           selectedIcon: Icons.water),
    _NavEntry(label: 'India',      icon: Icons.map_outlined,             selectedIcon: Icons.map),
  ];

  Widget _buildScreen(int index) {
    switch (index) {
      case 0: return const DashboardScreen();
      case 1: return const MonitorsScreen();
      case 2: return const AlertsScreen();
      case 3: return const WeatherScreen();
      case 4: return const PredictScreen();
      case 5: return const RiverMonitorScreen();
      case 6: return const IndiaRiverExplorerScreen();
      default: return const DashboardScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    _svc.startPolling();
  }

  @override
  void dispose() {
    _svc.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Lazy: only the active screen is in the tree at any time.
      body: _buildScreen(_currentIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavEntry {
  const _NavEntry({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
