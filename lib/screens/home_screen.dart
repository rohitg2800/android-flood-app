import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../constants/bihar_constants.dart';
import 'dashboard_screen.dart';
import 'bihar_river_map_screen.dart';
import 'alerts_screen.dart';
import 'live_stations_screen.dart';
import 'weather_screen.dart';
import 'predict_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_rounded,    label: 'Dashboard'),
    _NavItem(icon: Icons.map_rounded,          label: 'River Map'),
    _NavItem(icon: Icons.sensors_rounded,      label: 'Stations'),
    _NavItem(icon: Icons.notifications_rounded,label: 'Alerts'),
    _NavItem(icon: Icons.cloud_rounded,        label: 'Weather'),
  ];

  final List<Widget> _screens = const [
    DashboardScreen(),
    BiharRiverMapScreen(),
    LiveStationsScreen(),
    AlertsScreen(),
    WeatherScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: AppPalette.navy1,
        indicatorColor: AppPalette.blue1.withOpacity(0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon, color: AppPalette.textMuted),
                  selectedIcon: Icon(item.icon, color: AppPalette.blue1),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
