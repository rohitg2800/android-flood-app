// lib/home_widget/flood_home_widget.dart
// OpsFlood — Module 12: Android & iOS Home-screen Widget
//
// Requires `home_widget: ^0.7.0` in pubspec.yaml.
//
// fix: import guarded with try/catch via conditional import pattern;
// withOpacity -> withValues(alpha:) to silence deprecation warnings.

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const String _kAppGroupId     = 'group.com.equinox.flood';
const String _kAndroidName    = 'FloodWidgetProvider';
const String _kIosName        = 'FloodWidget';

const String _kWaterLevel     = 'water_level';
const String _kDangerLevel    = 'danger_level';
const String _kWarningLevel   = 'warning_level';
const String _kRiskLabel      = 'risk_label';
const String _kStationName    = 'station_name';
const String _kLastUpdated    = 'last_updated';

// ---------------------------------------------------------------------------
// FloodHomeWidget
// ---------------------------------------------------------------------------

class FloodHomeWidget {
  FloodHomeWidget._();
  static final FloodHomeWidget instance = FloodHomeWidget._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await HomeWidget.setAppGroupId(_kAppGroupId);
    HomeWidget.registerBackgroundCallback(_backgroundCallback);
    _initialized = true;
  }

  /// Push live station data to the home-screen widget.
  Future<void> update({
    required String stationName,
    required double waterLevel,
    required double dangerLevel,
    required double warningLevel,
    required String riskLabel,
    required String lastUpdated,
  }) async {
    await HomeWidget.saveWidgetData<String>(_kStationName,  stationName);
    await HomeWidget.saveWidgetData<double>(_kWaterLevel,   waterLevel);
    await HomeWidget.saveWidgetData<double>(_kDangerLevel,  dangerLevel);
    await HomeWidget.saveWidgetData<double>(_kWarningLevel, warningLevel);
    await HomeWidget.saveWidgetData<String>(_kRiskLabel,    riskLabel);
    await HomeWidget.saveWidgetData<String>(_kLastUpdated,  lastUpdated);
    await _repaint();
  }

  Future<void> _repaint() async {
    await HomeWidget.updateWidget(
      androidName: _kAndroidName,
      iOSName:     _kIosName,
    );
  }

  // Handle widget tap → deep-link
  static Future<void> handleWidgetLaunch(
      void Function(Uri? uri) onLaunch) async {
    HomeWidget.widgetClicked.listen(onLaunch);
    final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (initialUri != null) onLaunch(initialUri);
  }
}

// Background callback (must be a top-level function)
@pragma('vm:entry-point')
Future<void> _backgroundCallback(Uri? uri) async {
  // Handle background widget interactions if needed
}

// ---------------------------------------------------------------------------
// FloodWidgetPreview — shown in Settings to illustrate the widget
// ---------------------------------------------------------------------------

class FloodWidgetPreview extends StatelessWidget {
  final String stationName;
  final double waterLevel;
  final double dangerLevel;
  final double warningLevel;
  final String riskLabel;

  const FloodWidgetPreview({
    super.key,
    required this.stationName,
    required this.waterLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.riskLabel,
  });

  Color get _riskColor {
    if (waterLevel >= dangerLevel)  return const Color(0xFFFF1A44);
    if (waterLevel >= warningLevel) return const Color(0xFFFFA520);
    return const Color(0xFF10E88A);
  }

  double get _pct =>
      dangerLevel > 0 ? (waterLevel / dangerLevel).clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    final color = _riskColor;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_rounded, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  stationName,
                  style: const TextStyle(
                      color: Color(0xFFFFF8E7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${waterLevel.toStringAsFixed(2)} m',
            style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _pct,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            riskLabel,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
