// lib/models/flood_data.dart
// OpsFlood — FloodData model (canonical)

class FloodData {
  final String  stationId;
  final String  stationName;
  final String  river;
  final String  district;
  final double  currentLevel;
  final double  dangerLevel;
  final double  warningLevel;
  final double? previousLevel;
  final DateTime? observedAt;
  final String  trend;   // 'rising' | 'falling' | 'steady'

  const FloodData({
    required this.stationId,
    required this.stationName,
    required this.river,
    required this.district,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    this.previousLevel,
    this.observedAt,
    this.trend = 'steady',
  });

  /// Percentage of danger-level capacity (0–100+).
  /// river_monitor_screen.dart uses `data.fillPercent`.
  double get fillPercent =>
      dangerLevel > 0 ? (currentLevel / dangerLevel * 100).clamp(0, 150) : 0;

  bool get isAboveDanger   => currentLevel >= dangerLevel;
  bool get isAboveWarning  => currentLevel >= warningLevel;

  factory FloodData.fromJson(Map<String, dynamic> j) => FloodData(
        stationId:     j['station_id']    as String? ?? '',
        stationName:   j['station_name']  as String? ?? '',
        river:         j['river']         as String? ?? '',
        district:      j['district']      as String? ?? '',
        currentLevel:  (j['current_level']  as num?)?.toDouble() ?? 0,
        dangerLevel:   (j['danger_level']   as num?)?.toDouble() ?? 0,
        warningLevel:  (j['warning_level']  as num?)?.toDouble() ?? 0,
        previousLevel: (j['previous_level'] as num?)?.toDouble(),
        observedAt: j['observed_at'] != null
            ? DateTime.tryParse(j['observed_at'] as String)
            : null,
        trend: j['trend'] as String? ?? 'steady',
      );

  Map<String, dynamic> toJson() => {
        'station_id':    stationId,
        'station_name':  stationName,
        'river':         river,
        'district':      district,
        'current_level': currentLevel,
        'danger_level':  dangerLevel,
        'warning_level': warningLevel,
        if (previousLevel != null) 'previous_level': previousLevel,
        if (observedAt != null)
          'observed_at': observedAt!.toIso8601String(),
        'trend': trend,
      };
}
