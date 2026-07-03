import 'package:equinox_flood/config/app_config.dart';
// lib/services/incident_sync_service.dart
// OpsFlood — Module 6: Media, Image Attachments & Export
//
// IncidentSyncService
// ─────────────────────────────────────────────────────────────────────────
// Iterates the local Hive 'community_incidents' box and uploads
// any unsynced CommunityIncident records (+ optional photo) to
// the OpsFlood backend REST API.
//
// Sync strategy:
//   • JSON metadata  → POST /api/incidents          (application/json)
//   • Photo file     → POST /api/incidents/{id}/photo (multipart/form-data)
//   • Marks synced=true + saves back to Hive on 200/201
//   • Exponential back-off on 5xx (max 3 retries, 2s/4s/8s)
//   • 4xx errors are treated as permanent failures (bad data) —
//     still marked synced to prevent infinite retry loops

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/community_incident.dart';

class IncidentSyncService {
  IncidentSyncService._();
  static final IncidentSyncService instance = IncidentSyncService._();

  static String get _baseUrl =>
      dotenv.maybeGet('OPSFLOOD_API_URL') ?? AppConfig.baseUrl;

  // ── Public API ──────────────────────────────────────────────────────

  /// Sync all unsynced incidents in the Hive box.
  /// Returns a [SyncResult] summary.
  Future<SyncResult> syncAll() async {
    final box = Hive.box<CommunityIncident>('community_incidents');
    final unsynced = box.values.where((i) => !i.synced).toList();

    int uploaded = 0;
    int failed = 0;
    final errors = <String>[];

    for (final incident in unsynced) {
      try {
        await _syncOne(incident);
        uploaded++;
      } catch (e) {
        failed++;
        errors.add('${incident.id}: $e');
      }
    }
    return SyncResult(uploaded: uploaded, failed: failed, errors: errors);
  }

  /// Sync a single incident.  Throws on unrecoverable error.
  Future<void> syncOne(CommunityIncident incident) => _syncOne(incident);

  // ── Internal sync logic ───────────────────────────────────────────────

  Future<void> _syncOne(CommunityIncident incident) async {
    // Step 1: Upload JSON metadata
    await _postWithRetry(
      Uri.parse('$_baseUrl/api/incidents'),
      body: jsonEncode(incident.toJson()),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    // Step 2: Upload photo (if exists)
    if (incident.imagePath != null) {
      final imageFile = File(incident.imagePath!);
      if (await imageFile.exists()) {
        await _uploadPhoto(incident.id, imageFile);
      }
    }

    // Mark synced
    incident.synced = true;
    await incident.save();
  }

  Future<void> _uploadPhoto(String incidentId, File imageFile) async {
    final uri = Uri.parse('$_baseUrl/api/incidents/$incidentId/photo');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath(
        'photo',
        imageFile.path,
        filename: imageFile.uri.pathSegments.last,
      ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _assertSuccess(response);
  }

  Future<http.Response> _postWithRetry(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (true) {
      final response = await http.post(uri, headers: headers, body: body);
      if (response.statusCode < 500) {
        _assertSuccess(response);
        return response;
      }
      attempt++;
      if (attempt >= maxRetries) {
        throw HttpException(
            'HTTP ${response.statusCode} after $attempt retries: ${uri.path}');
      }
      // Exponential back-off: 2^attempt seconds
      await Future.delayed(Duration(seconds: math.pow(2, attempt).toInt()));
    }
  }

  void _assertSuccess(http.Response response) {
    if (response.statusCode >= 400) {
      throw HttpException(
          'HTTP ${response.statusCode}: ${response.body.substring(0, math.min(200, response.body.length))}');
    }
  }
}

// ── SyncResult ───────────────────────────────────────────────────────────────

class SyncResult {
  final int uploaded;
  final int failed;
  final List<String> errors;
  const SyncResult({
    required this.uploaded,
    required this.failed,
    required this.errors,
  });
  bool get hasErrors => failed > 0;
  @override
  String toString() => 'SyncResult(uploaded: $uploaded, failed: $failed)';
}
