// lib/utils/haptic_service.dart
// Severity-differentiated haptic feedback service.
// Call HapticService.forSeverity(severity) on any alert state change.

import 'package:flutter/services.dart';

enum HapticSeverity { critical, severe, moderate, low, resolved }

class HapticService {
  HapticService._();

  static Future<void> forSeverity(HapticSeverity severity) async {
    switch (severity) {
      case HapticSeverity.critical:
        // Triple heavy — unmissable
        for (int i = 0; i < 3; i++) {
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 400));
        }
      case HapticSeverity.severe:
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 300));
        await HapticFeedback.mediumImpact();
      case HapticSeverity.moderate:
        await HapticFeedback.mediumImpact();
      case HapticSeverity.low:
        await HapticFeedback.lightImpact();
      case HapticSeverity.resolved:
        await HapticFeedback.selectionClick();
    }
  }

  /// Map raw severity string from backend to HapticSeverity
  static HapticSeverity fromString(String s) {
    switch (s.toUpperCase()) {
      case 'CRITICAL':
      case 'EMERGENCY':
        return HapticSeverity.critical;
      case 'SEVERE':
        return HapticSeverity.severe;
      case 'MODERATE':
      case 'WARNING':
        return HapticSeverity.moderate;
      case 'RESOLVED':
      case 'NORMAL':
        return HapticSeverity.resolved;
      default:
        return HapticSeverity.low;
    }
  }
}
