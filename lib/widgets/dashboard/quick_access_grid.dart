// lib/widgets/dashboard/quick_access_grid.dart
// Extracted from dashboard_screen.dart — quick-navigation shortcut grid.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuickAccessGrid extends StatelessWidget {
  const QuickAccessGrid({super.key});

  static const _items = [
    _QuickItem(icon: Icons.map_outlined, label: 'River Map', route: '/map'),
    _QuickItem(
        icon: Icons.analytics_outlined, label: 'Predict', route: '/predict'),
    _QuickItem(
        icon: Icons.notifications_outlined, label: 'Alerts', route: '/alerts'),
    _QuickItem(icon: Icons.cloud_outlined, label: 'Weather', route: '/weather'),
    _QuickItem(icon: Icons.sos_outlined, label: 'SOS', route: '/sos'),
    _QuickItem(
        icon: Icons.settings_outlined, label: 'Settings', route: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
        children: _items.map((item) => _GridCell(item: item)).toList(),
      ),
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String label;
  final String route;
  const _QuickItem(
      {required this.icon, required this.label, required this.route});
}

class _GridCell extends StatelessWidget {
  final _QuickItem item;
  const _GridCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pushNamed(context, item.route);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 26, color: Colors.white70),
            const SizedBox(height: 6),
            Text(
              item.label,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
