import "package:flutter/material.dart";

class DashboardTile {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  final String? badge;

  const DashboardTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
    this.badge,
  });
}