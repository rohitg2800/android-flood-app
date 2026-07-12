import 'dart:convert';
import 'package:http/http.dart' as http;
import 'neon_auth_service.dart';

/// REST API service — all requests include the JWT Bearer token.
/// Backend should verify the JWT using the JWKS URL and enforce RLS.
class FloodApiService {
  // Replace with your actual backend base URL (e.g. a Dart Frog / Node / FastAPI server
  // that proxies authenticated requests to Neon).
  static const String _baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080/api');

  // ─── Flood Alerts ─────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getActiveAlerts() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/flood-alerts?is_active=true'),
      headers: NeonAuthService.authHeaders,
    );
    return _parseList(res);
  }

  static Future<Map<String, dynamic>> createAlert(
      Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/flood-alerts'),
      headers: NeonAuthService.authHeaders,
      body: jsonEncode(payload),
    );
    return _parseMap(res);
  }

  // ─── Incidents ────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getIncidents({
    String? status,
  }) async {
    final query = status != null ? '?status=$status' : '';
    final res = await http.get(
      Uri.parse('$_baseUrl/incidents$query'),
      headers: NeonAuthService.authHeaders,
    );
    return _parseList(res);
  }

  static Future<Map<String, dynamic>> reportIncident(
      Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/incidents'),
      headers: NeonAuthService.authHeaders,
      body: jsonEncode(payload),
    );
    return _parseMap(res);
  }

  static Future<Map<String, dynamic>> updateIncidentStatus(
      String id, String status) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl/incidents/$id'),
      headers: NeonAuthService.authHeaders,
      body: jsonEncode({'status': status}),
    );
    return _parseMap(res);
  }

  // ─── Relief Camps ─────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getActiveReliefCamps() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/relief-camps?is_active=true'),
      headers: NeonAuthService.authHeaders,
    );
    return _parseList(res);
  }

  // ─── Water Level Readings ─────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getLatestWaterLevels() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/water-levels?order=recorded_at.desc&limit=50'),
      headers: NeonAuthService.authHeaders,
    );
    return _parseList(res);
  }

  // ─── Helpers ──────────────────────────────────────────────────
  static List<Map<String, dynamic>> _parseList(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
    }
    throw Exception('API error ${res.statusCode}: ${res.body}');
  }

  static Map<String, dynamic> _parseMap(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('API error ${res.statusCode}: ${res.body}');
  }
}
