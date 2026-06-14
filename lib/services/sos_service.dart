// lib/services/sos_service.dart
// Phase 5 — SOS Service
//
// Responsibilities:
//   1. Acquire GPS coordinates via geolocator
//   2. Build an SMS/call URI and launch it via url_launcher
//   3. Return a typed SosResult so the provider can reflect state

import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Contacts dispatched on SOS ────────────────────────────────────────────────
class EmergencyContact {
  final String name;
  final String phone;
  final String role;
  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.role,
  });
}

const kEmergencyContacts = [
  EmergencyContact(
      name: 'NDRF Control Room',
      phone: '01124363260',
      role: 'National Disaster Response Force'),
  EmergencyContact(
      name: 'Bihar SDMA',
      phone: '06122294204',
      role: 'State Disaster Management Authority'),
  EmergencyContact(
      name: 'Flood Control Room',
      phone: '06122215870',
      role: 'Bihar Water Resources Dept.'),
  EmergencyContact(
      name: 'Police Emergency',
      phone: '100',
      role: 'Bihar Police'),
  EmergencyContact(
      name: 'Ambulance',
      phone: '108',
      role: 'Emergency Medical Services'),
];

// ── Result type ───────────────────────────────────────────────────────────────
sealed class SosResult {}

final class SosSuccess extends SosResult {
  final double? lat;
  final double? lng;
  SosSuccess({this.lat, this.lng});
}

final class SosFailure extends SosResult {
  final String reason;
  SosFailure(this.reason);
}

// ── Service ───────────────────────────────────────────────────────────────────
class SosService {
  /// Acquire GPS → open SMS to primary NDRF number with location in body.
  /// Falls back to plain phone call if SMS fails to launch.
  Future<SosResult> dispatch() async {
    double? lat;
    double? lng;

    // 1. Try to get location (best effort — don't block SOS on denial)
    try {
      final permission = await Geolocator.checkPermission();
      LocationPermission perm = permission;
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {
      // Location unavailable — proceed without it
    }

    // 2. Build SMS URI to NDRF
    final primary = kEmergencyContacts.first;
    final body = lat != null
        ? 'FLOOD SOS EMERGENCY. My location: https://maps.google.com/?q=$lat,$lng'
        : 'FLOOD SOS EMERGENCY. Location unavailable. Please help immediately.';

    final smsUri = Uri(
      scheme: 'sms',
      path: primary.phone,
      queryParameters: {'body': body},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
      return SosSuccess(lat: lat, lng: lng);
    }

    // 3. Fallback: open dialler to primary number
    final callUri = Uri(scheme: 'tel', path: primary.phone);
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
      return SosSuccess(lat: lat, lng: lng);
    }

    return SosFailure('Could not launch SMS or dialler.');
  }

  /// Direct call to any emergency contact.
  Future<void> call(EmergencyContact contact) async {
    final uri = Uri(scheme: 'tel', path: contact.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
