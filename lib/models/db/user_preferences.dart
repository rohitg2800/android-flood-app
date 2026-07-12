// Plain Dart model — no freezed / json_serializable
// Maps to: public.user_preferences

class UserPreferences {
  final String id;
  final String userId;
  final bool notificationsEnabled;
  final bool smsAlertsEnabled;
  final bool emailAlertsEnabled;
  final String language;
  final String theme; // 'light' | 'dark' | 'system'
  final String? preferredDistrict;
  final List<String> subscribedZones;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserPreferences({
    required this.id,
    required this.userId,
    this.notificationsEnabled = true,
    this.smsAlertsEnabled = false,
    this.emailAlertsEnabled = true,
    this.language = 'en',
    this.theme = 'system',
    this.preferredDistrict,
    this.subscribedZones = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) => UserPreferences(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
        smsAlertsEnabled: json['sms_alerts_enabled'] as bool? ?? false,
        emailAlertsEnabled: json['email_alerts_enabled'] as bool? ?? true,
        language: json['language'] as String? ?? 'en',
        theme: json['theme'] as String? ?? 'system',
        preferredDistrict: json['preferred_district'] as String?,
        subscribedZones:
            (json['subscribed_zones'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'notifications_enabled': notificationsEnabled,
        'sms_alerts_enabled': smsAlertsEnabled,
        'email_alerts_enabled': emailAlertsEnabled,
        'language': language,
        'theme': theme,
        'preferred_district': preferredDistrict,
        'subscribed_zones': subscribedZones,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  UserPreferences copyWith({
    String? id,
    String? userId,
    bool? notificationsEnabled,
    bool? smsAlertsEnabled,
    bool? emailAlertsEnabled,
    String? language,
    String? theme,
    String? preferredDistrict,
    List<String>? subscribedZones,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      UserPreferences(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        smsAlertsEnabled: smsAlertsEnabled ?? this.smsAlertsEnabled,
        emailAlertsEnabled: emailAlertsEnabled ?? this.emailAlertsEnabled,
        language: language ?? this.language,
        theme: theme ?? this.theme,
        preferredDistrict: preferredDistrict ?? this.preferredDistrict,
        subscribedZones: subscribedZones ?? this.subscribedZones,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UserPreferences && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
