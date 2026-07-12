// lib/widgets/ops_icons.dart
// Custom icon set used across OpsFlood screens.

import 'package:flutter/material.dart';

// ─ Icon code-points (Material Symbols subset) ─────────────────────────────
class OpsIcons {
  OpsIcons._();

  static const IconData dashboard = Icons.dashboard_outlined;
  static const IconData alerts = Icons.notifications_active_outlined;
  static const IconData map = Icons.map_outlined;
  static const IconData community = Icons.people_outline; // fix: was missing
  static const IconData export = Icons.ios_share_outlined; // fix: was missing
  static const IconData settings = Icons.settings_outlined;
  static const IconData river = Icons.water_outlined;
  static const IconData rain = Icons.water_drop_outlined;
  static const IconData flood = Icons.flood_outlined;
  static const IconData warning = Icons.warning_amber_outlined;
  static const IconData emergency = Icons.emergency_outlined;
  static const IconData info = Icons.info_outline;
  static const IconData share = Icons.share_outlined;
  static const IconData whatsapp = Icons.chat_outlined;
  static const IconData copy = Icons.copy_outlined;
  static const IconData refresh = Icons.refresh;
  static const IconData location = Icons.location_on_outlined;
  static const IconData chart = Icons.bar_chart_outlined;
  static const IconData history = Icons.history_outlined;
  static const IconData station = Icons.sensors_outlined;
  static const IconData forecast = Icons.air_outlined;
}

// ─ OpsIcon widget ────────────────────────────────────────────────────────
class OpsIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  const OpsIcon(this.icon, {super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) => Icon(icon, size: size, color: color);
}
