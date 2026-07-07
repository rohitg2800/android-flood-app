class UserModel {
  final String id;
  final String email;
  final String role; // admin | field_agent | citizen
  final String name;
  final String? phone;

  UserModel({required this.id, required this.email, required this.role, required this.name, this.phone});

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    email: json['email'],
    role: json['role'],
    name: json['name'],
    phone: json['phone'],
  );
}
