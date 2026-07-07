// Core: Neon API Service
// Handles all REST calls to the Neon-backed API server
import 'dart:convert';
import 'package:http/http.dart' as http;

class NeonApiService {
  final String baseUrl;
  final String? authToken;

  NeonApiService({required this.baseUrl, this.authToken});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  // Alerts
  Future<List<dynamic>> getActiveAlerts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/alerts?active=true'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    throw Exception('Failed to load alerts: ${response.statusCode}');
  }

  // Incidents
  Future<List<dynamic>> getIncidents({String? status}) async {
    final uri = Uri.parse('$baseUrl/api/incidents')
        .replace(queryParameters: status != null ? {'status': status} : null);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    throw Exception('Failed to load incidents: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> createIncident(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/incidents'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create incident: ${response.statusCode}');
  }

  // Relief Camps
  Future<List<dynamic>> getReliefCamps({String? district}) async {
    final uri = Uri.parse('$baseUrl/api/camps')
        .replace(queryParameters: district != null ? {'district': district} : null);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    throw Exception('Failed to load camps: ${response.statusCode}');
  }

  // Water Levels
  Future<List<dynamic>> getWaterLevelReadings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/water-levels'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    throw Exception('Failed to load water levels: ${response.statusCode}');
  }
}
