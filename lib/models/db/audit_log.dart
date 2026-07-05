// Plain Dart model — no freezed / json_serializable
// Maps to: public.audit_logs

enum AuditAction { create, update, delete, login, logout, view, export }

AuditAction auditActionFromString(String s) =>
    AuditAction.values.firstWhere((e) => e.name == s,
        orElse: () => AuditAction.view);

class AuditLog {
  final String id;
  final String? userId;
  final AuditAction action;
  final String resourceType; // e.g. 'flood_alert', 'sos_report'
  final String? resourceId;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    this.userId,
    required this.action,
    required this.resourceType,
    this.resourceId,
    this.oldValues,
    this.newValues,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
        id: json['id'] as String,
        userId: json['user_id'] as String?,
        action: auditActionFromString(json['action'] as String),
        resourceType: json['resource_type'] as String,
        resourceId: json['resource_id'] as String?,
        oldValues: json['old_values'] as Map<String, dynamic>?,
        newValues: json['new_values'] as Map<String, dynamic>?,
        ipAddress: json['ip_address'] as String?,
        userAgent: json['user_agent'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'action': action.name,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'old_values': oldValues,
        'new_values': newValues,
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AuditLog && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AuditLog(action: ${action.name}, resource: $resourceType/$resourceId)';
}
