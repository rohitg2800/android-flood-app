// lib/services/background_service.dart
// Phase 2 Stability Fix
//
// flutter_background_service was conflicting with workmanager on Android 12+
// causing ForegroundServiceStartNotAllowedException.
//
// Resolution: flutter_background_service is DISABLED here.
// All background sync is handled exclusively by WorkManager (workmanager package)
// via ai_prediction_background_service.dart and pipeline_service.dart.
//
// Do NOT re-enable flutter_background_service without removing workmanager first.
library;

class BackgroundServiceShim {
  // Intentionally empty. See ai_prediction_background_service.dart
  // for the active WorkManager-based background task registration.
  static void init() {
    // no-op: background tasks run through WorkManager only.
  }
}
