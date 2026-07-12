enum MotorAction { startPump, stopPump, emergencyStop, setSchedule }

class MotorLog {
  final String id;
  final String stationId;
  final MotorAction action;
  final DateTime timestamp;
  final String? reason;
  final bool success;

  const MotorLog({
    required this.id,
    required this.stationId,
    required this.action,
    required this.timestamp,
    this.reason,
    required this.success,
  });

  factory MotorLog.fromJson(Map<String, dynamic> j) => MotorLog(
        id: j['id'] as String,
        stationId: j['station_id'] as String,
        action: MotorAction.values.byName(
            (j['action'] as String).replaceAll('-', '_')),
        timestamp: DateTime.parse(j['timestamp'] as String),
        reason: j['reason'] as String?,
        success: j['success'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'station_id': stationId,
        'action': action.name,
        'timestamp': timestamp.toIso8601String(),
        if (reason != null) 'reason': reason,
        'success': success,
      };
}
