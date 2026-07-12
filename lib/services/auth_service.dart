import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/auth/auth_user.dart';
import '../models/auth/auth_session.dart';
import '../config/env_config.dart';

/// AuthService handles all Better Auth (Neon Auth) REST API calls.
/// JWT is stored securely using flutter_secure_storage.
class AuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'auth_token';
  static const _sessionKey = 'auth_session';

  static String get _baseUrl => EnvConfig.betterAuthUrl;

  // ---------------------------------------------------------------------------
  // Token Management
  // ---------------------------------------------------------------------------

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _sessionKey);
  }

  static Future<bool> hasValidToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Auth Headers
  // ---------------------------------------------------------------------------

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ---------------------------------------------------------------------------
  // Sign Up
  // ---------------------------------------------------------------------------

  static Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/sign-up/email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = data['token'] as String?;
        if (token != null) await saveToken(token);
        return AuthResult.success(
          user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
          token: token,
        );
      } else {
        return AuthResult.error(data['message'] as String? ?? 'Signup failed');
      }
    } catch (e) {
      return AuthResult.error('Network error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Sign In
  // ---------------------------------------------------------------------------

  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/sign-in/email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final token = data['token'] as String?;
        if (token != null) await saveToken(token);
        return AuthResult.success(
          user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
          token: token,
        );
      } else {
        return AuthResult.error(data['message'] as String? ?? 'Invalid credentials');
      }
    } catch (e) {
      return AuthResult.error('Network error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Get Current User (/auth/me proxied via FastAPI)
  // ---------------------------------------------------------------------------

  static Future<AuthUser?> getCurrentUser() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('${EnvConfig.apiBaseUrl}/auth/me'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AuthUser.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------

  static Future<void> signOut() async {
    try {
      final headers = await getAuthHeaders();
      await http.post(
        Uri.parse('$_baseUrl/auth/sign-out'),
        headers: headers,
      );
    } catch (_) {}
    await deleteToken();
  }

  // ---------------------------------------------------------------------------
  // Forgot Password
  // ---------------------------------------------------------------------------

  static Future<AuthResult> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/forget-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) {
        return AuthResult.success();
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AuthResult.error(data['message'] as String? ?? 'Request failed');
      }
    } catch (e) {
      return AuthResult.error('Network error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Session Refresh
  // ---------------------------------------------------------------------------

  static Future<String?> refreshSession() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh-token'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newToken = data['token'] as String?;
        if (newToken != null) await saveToken(newToken);
        return newToken;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// AuthResult sealed-class-style helper
// ---------------------------------------------------------------------------

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final AuthUser? user;
  final String? token;

  const AuthResult._(
      {required this.isSuccess,
      this.errorMessage,
      this.user,
      this.token});

  factory AuthResult.success({AuthUser? user, String? token}) =>
      AuthResult._(isSuccess: true, user: user, token: token);

  factory AuthResult.error(String message) =>
      AuthResult._(isSuccess: false, errorMessage: message);
}
