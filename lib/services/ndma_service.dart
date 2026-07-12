// lib/services/ndma_service.dart
//
// OpsFlood — NDMA Advisories + Emergency Contacts
//
// All calls go through FloodApi → OpsClient (auth, retry, timeouts).
// Endpoints are defined in AppConfig — no magic URL strings.
library;

import 'package:flutter/foundation.dart';
import 'flood_api.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class EmergencyContact {
  final String role;
  final String name;
  final String phone;
  final String state;

  const EmergencyContact({
    required this.role,
    required this.name,
    required this.phone,
    required this.state,
  });
}

// ── NdmaService ──────────────────────────────────────────────────────────────

class NdmaService {
  NdmaService._();
  static final NdmaService instance = NdmaService._();

  final FloodApi _api = FloodApi.instance;

  /// Returns raw advisory maps from the backend.
  /// The backend proxies data.ndma.gov.in and caches it server-side.
  Future<List<dynamic>> fetchAdvisories(String state) async {
    try {
      final raw = await _api.ndmaAdvisories(state);
      // Unwrap if backend wraps in { data: [...] }
      if (raw['data'] is List) return raw['data'] as List<dynamic>;
      if (raw is List) return raw as List<dynamic>;
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('[NdmaService] fetchAdvisories $state: $e');
      return [];
    }
  }

  /// Returns typed emergency contacts for a state.
  Future<List<EmergencyContact>> fetchEmergencyContacts(String state) async {
    try {
      final raw = await _api.ndmaContacts(state);
      final list = raw['data'] is List
          ? raw['data'] as List<dynamic>
          : (raw is List ? raw as List<dynamic> : <dynamic>[]);
      return list
          .whereType<Map<String, dynamic>>()
          .map((m) => EmergencyContact(
                role: m['role']?.toString() ?? '',
                name: m['name']?.toString() ?? '',
                phone: m['phone']?.toString() ?? '',
                state: m['state']?.toString() ?? state,
              ))
          .toList();
    } catch (e) {
      if (kDebugMode)
        debugPrint('[NdmaService] fetchEmergencyContacts $state: $e');
      return [];
    }
  }
}
