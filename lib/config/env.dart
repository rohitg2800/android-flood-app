// lib/config/env.dart
// EQUINOX-BH — Environment variable helpers

import 'app_config.dart';

class Env {
  Env._();

  /// Returns true when the app is running in a debug build.
  static bool get isDebug {
    bool debug = false;
    assert(() {
      debug = true;
      return true;
    }());
    return debug;
  }

  /// The active backend base URL.
  /// In production this is the Render-hosted service.
  /// In development it can be overridden at build time:
  /// which is wired via --dart-define=EQUINOX_BH_BASE_URL at build time.
  static String get backendBaseUrl {
    if (isDebug && AppConfig.baseUrl == 'https://android-flood-app-production.up.railway.app') {
      return 'http://localhost:8000';
    }
    return AppConfig.baseUrl; 
  }
}
