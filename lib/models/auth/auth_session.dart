/// Represents a session from neon_auth.session table.
class AuthSession {
  final String id;
  final String userId;
  final String token;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String? ipAddress;
  final String? userAgent;

  const AuthSession({
    required this.id,
    required this.userId,
    required this.token,
    required this.expiresAt,
    required this.createdAt,
    this.ipAddress,
    this.userAgent,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      id: json['id'] as String,
      userId: json['userId'] as String,
      token: json['token'] as String,
      expiresAt:
          DateTime.parse(json['expiresAt'] as String),
      createdAt:
          DateTime.parse(json['createdAt'] as String),
      ipAddress: json['ipAddress'] as String?,
      userAgent: json['userAgent'] as String?,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Returns true if the session expires within the next [minutes] minutes.
  bool expiresWithin(int minutes) =>
      DateTime.now()
          .add(Duration(minutes: minutes))
          .isAfter(expiresAt);
}
