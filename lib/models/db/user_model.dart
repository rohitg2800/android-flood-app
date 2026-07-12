// Plain Dart model — no freezed / json_serializable
// Maps to: public.users

class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? phone;
  final String? avatarUrl;
  final String? district;
  final String? state;
  final double? latitude;
  final double? longitude;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.phone,
    this.avatarUrl,
    this.district,
    this.state,
    this.latitude,
    this.longitude,
    this.emailVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String?,
        phone: json['phone'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        district: json['district'] as String?,
        state: json['state'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        emailVerified: json['email_verified'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'phone': phone,
        'avatar_url': avatarUrl,
        'district': district,
        'state': state,
        'latitude': latitude,
        'longitude': longitude,
        'email_verified': emailVerified,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? avatarUrl,
    String? district,
    String? state,
    double? latitude,
    double? longitude,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      UserModel(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        district: district ?? this.district,
        state: state ?? this.state,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        emailVerified: emailVerified ?? this.emailVerified,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  String toString() => 'UserModel(id: $id, email: $email, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UserModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
