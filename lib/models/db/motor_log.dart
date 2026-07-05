// Plain Dart model — no freezed / json_serializable
// Maps to: public.motor_logs

enum MotorAction { start, stop, fault, maintenance, auto_start, auto_stop }

MotorAction motorActionFromString(String s) =>
    MotorAction.values.firstWhere((e) => e.name == s,
        orElse: () => MotorAction.stop);

class MotorLog {
  final String id;
  final String pumpStationId;
  final MotorAction action;
  final String? triggeredBy; // user_id or 'system'
  final double? waterLevelAtTime;
  final String? notes;
  final DateTime actionAt;
  final DateTime createdAt;

  const MotorLog({
    required this.id,
    required this.pumpStationId,
    required this.action,
    this.triggeredBy,
    this.waterLevelAtTime,
    this.notes,
    required this.actionAt,
    required this.createdAt,
  });

  factory MotorLog.fromJson(Map<String, dynamic> json) => MotorLog(
        id: json['id'] as String,
        pumpStationId: json['pump_station_id'] as String,
        action: motorActionFromString(json['action'] as String),
        triggeredBy: json['triggered_by'] as String?,
        waterLevelAtTime: (json['water_level_at_time'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        actionAt: DateTime.parse(json['action_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'pump_station_id': pumpStationId,
        'action': action.name,
        'triggered_by': triggeredBy,
        'water_level_at_time': waterLevelAtTime,
        'notes': notes,
        'action_at': actionAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  bool get isAutomated =>
      action == MotorAction.auto_start || action == MotorAction.auto_stop;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MotorLog && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MotorLog(pumpStation: $pumpStationId, action: ${action.name}, at: $actionAt)';
}
