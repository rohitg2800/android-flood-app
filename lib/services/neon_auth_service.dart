import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/neon_config.dart';

/// Handles JWT auth against Neon Auth (Better Auth compatible).
class NeonAuthService {
  static String? _accessToken;
  static String? _userRole;
  static String? _userId;

  // ─── Sign In ────────────────────────────────────────────────
  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(NeonConfig.signInUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = data['token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      _userId = user?['id'] as String?;
      _userRole = user?['role'] as String? ?? 'citizen';
      return AuthResult.success(token: _accessToken!, role: _userRole!);
    }
    return AuthResult.failure(message: 'Sign in failed: ${response.body}');
  }

  // ─── Sign Up ─────────────────────────────────────────────────
  static Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'citizen',
  }) async {
    final response = await http.post(
      Uri.parse(NeonConfig.signUpUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
        'role': role,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = data['token'] as String?;
      _userRole = role;
      return AuthResult.success(token: _accessToken!, role: _userRole!);
    }
    return AuthResult.failure(message: 'Sign up failed: ${response.body}');
  }

  // ─── Sign Out ────────────────────────────────────────────────
  static Future<void> signOut() async {
    if (_accessToken != null) {
      await http.post(
        Uri.parse(NeonConfig.signOutUrl),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );
    }
    _accessToken = null;
    _userRole = null;
    _userId = null;
  }

  // ─── Getters ─────────────────────────────────────────────────
  static String? get accessToken => _accessToken;
  static String? get userRole => _userRole;
  static String? get userId => _userId;
  static bool get isSignedIn => _accessToken != null;

  /// Returns auth headers to attach to every API request.
  static Map<String, String> get authHeaders => isSignedIn
      ? {'Authorization': 'Bearer $_accessToken', 'Content-Type': 'application/json'}
      : {'Content-Type': 'application/json'};
}

// ─── Result type ─────────────────────────────────────────────
class AuthResult {
  final bool success;
  final String? token;
  final String? role;
  final String? message;

  AuthResult._({required this.success, this.token, this.role, this.message});

  factory AuthResult.success({required String token, required String role}) =>
      AuthResult._(success: true, token: token, role: role);

  factory AuthResult.failure({required String message}) =>
      AuthResult._(success: false, message: message);
}
