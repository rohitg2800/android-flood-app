// Plain Dart model — no freezed / json_serializable
// Maps to: public.notifications
// Named FloodNotification to avoid conflict with Flutter SDK Notification class

enum NotificationType {
  flood_alert,
  water_level,
  sos_update,
  relief_camp,
  system,
  weather,
}

enum NotificationStatus { unread, read, dismissed }

NotificationType notificationTypeFromString(String s) =>
    NotificationType.values.firstWhere((e) => e.name == s,
        orElse: () => NotificationType.system);

NotificationStatus notificationStatusFromString(String s) =>
    NotificationStatus.values.firstWhere((e) => e.name == s,
        orElse: () => NotificationStatus.unread);

class FloodNotification {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final NotificationType type;
  final NotificationStatus status;
  final String? referenceId; // e.g. alert_id or sos_id
  final String? referenceType; // e.g. 'flood_alert', 'sos_report'
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime createdAt;

  const FloodNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    required this.type,
    required this.status,
    this.referenceId,
    this.referenceType,
    this.data,
    this.readAt,
    required this.createdAt,
  });

  factory FloodNotification.fromJson(Map<String, dynamic> json) =>
      FloodNotification(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        type: notificationTypeFromString(json['type'] as String),
        status: notificationStatusFromString(json['status'] as String),
        referenceId: json['reference_id'] as String?,
        referenceType: json['reference_type'] as String?,
        data: json['data'] as Map<String, dynamic>?,
        readAt: json['read_at'] != null
            ? DateTime.parse(json['read_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type.name,
        'status': status.name,
        'reference_id': referenceId,
        'reference_type': referenceType,
        'data': data,
        'read_at': readAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  bool get isUnread => status == NotificationStatus.unread;

  FloodNotification markAsRead() => FloodNotification(
        id: id,
        userId: userId,
        title: title,
        body: body,
        type: type,
        status: NotificationStatus.read,
        referenceId: referenceId,
        referenceType: referenceType,
        data: data,
        readAt: DateTime.now(),
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FloodNotification && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FloodNotification(id: $id, type: ${type.name}, status: ${status.name})';
}
