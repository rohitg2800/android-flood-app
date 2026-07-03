// lib/widgets/ops_icon.dart
// EQUINOX-BH — Module 2: Branding & Icons
//
// OpsIcon — thin wrapper around SvgPicture.asset for the project's icon set.
// Provides a typed enum + single call-site so switching icons is trivial.
//
// Usage:
//   OpsIcon(OpsIcons.station, size: 20, color: AppPalette.cyan)
//   OpsIcon(OpsIcons.alert,   size: 16)

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/river_theme.dart';

/// All SVG icons shipped in assets/icons/
enum OpsIcons {
  station, // ic_station.svg   — gauge pole
  alert, // ic_alert.svg     — warning triangle
  river, // ic_river.svg     — flowing waves
  district, // ic_district.svg  — map pin
  rainfall, // ic_rainfall.svg  — rain cloud
  forecast, // ic_forecast.svg  — clock + trend arrow
  wave, // ic_wave.svg      — flood surge
  shield, // ic_shield.svg    — safety / NDMA
  community, // ic_community.svg — group of people (Community screen)
  export, // ic_export.svg    — share/upload arrow  (Export screen)
}

extension _OpsIconsPath on OpsIcons {
  String get path {
    switch (this) {
      case OpsIcons.station:
        return 'assets/icons/ic_station.svg';
      case OpsIcons.alert:
        return 'assets/icons/ic_alert.svg';
      case OpsIcons.river:
        return 'assets/icons/ic_river.svg';
      case OpsIcons.district:
        return 'assets/icons/ic_district.svg';
      case OpsIcons.rainfall:
        return 'assets/icons/ic_rainfall.svg';
      case OpsIcons.forecast:
        return 'assets/icons/ic_forecast.svg';
      case OpsIcons.wave:
        return 'assets/icons/ic_wave.svg';
      case OpsIcons.shield:
        return 'assets/icons/ic_shield.svg';
      case OpsIcons.community:
        return 'assets/icons/ic_community.svg';
      case OpsIcons.export:
        return 'assets/icons/ic_export.svg';
    }
  }

  String get semanticsLabel {
    switch (this) {
      case OpsIcons.station:
        return 'River gauge station';
      case OpsIcons.alert:
        return 'Flood alert';
      case OpsIcons.river:
        return 'River';
      case OpsIcons.district:
        return 'District';
      case OpsIcons.rainfall:
        return 'Rainfall';
      case OpsIcons.forecast:
        return 'Forecast';
      case OpsIcons.wave:
        return 'Flood wave';
      case OpsIcons.shield:
        return 'Safety advisory';
      case OpsIcons.community:
        return 'Community reports';
      case OpsIcons.export:
        return 'Export data';
    }
  }
}

class OpsIcon extends StatelessWidget {
  final OpsIcons icon;
  final double size;

  /// Override colour. Null = use icon's own embedded colours (no tint).
  final Color? color;

  const OpsIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final _ = RiverColors.of(context);
    // Only apply tint if caller provides an explicit colour
    final cf = color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null;

    return SvgPicture.asset(
      icon.path,
      height: size,
      width: size,
      colorFilter: cf,
      semanticsLabel: icon.semanticsLabel,
    );
  }
}
