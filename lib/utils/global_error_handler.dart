// lib/utils/global_error_handler.dart
// GlobalErrorHandler — Phase 6 QA safety net.
//
// Catches ALL uncaught Flutter + platform errors before they silently
// white-screen the app. In release: reports to Firebase Crashlytics.
// In debug: prints full stack trace to console.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class GlobalErrorHandler {
  GlobalErrorHandler._();

  /// Call once, BEFORE runApp(), inside runZonedGuarded.
  static void init() {
    // Flutter framework errors (widget build errors, assertion failures, etc.)
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kReleaseMode) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    // Platform dispatcher errors (dart:async zone errors that
    // escape the widget tree — e.g. unhandled Future rejections)
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kReleaseMode) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } else {
        debugPrint('[FATAL] Uncaught platform error: $error\n$stack');
      }
      return true; // Mark as handled so the app doesn't hard-crash
    };
  }

  /// Call inside the runZonedGuarded body to catch zone-escaped errors.
  static void onZoneError(Object error, StackTrace stack) {
    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
    } else {
      debugPrint('[ZONE ERROR] $error\n$stack');
    }
  }
}
