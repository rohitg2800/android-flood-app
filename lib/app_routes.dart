import 'package:flutter/foundation.dart';

/// Central route definitions for the Flutter app.
///
/// Keeps both:
/// - `path` strings (for GoRouter / route matching)
/// - `name` strings (for navigation using named routes)
class AppRoutes {
  AppRoutes._();

  // ── Core flow ─────────────────────────────────────────────────────────────
  static const String splashPath = '/';
  static const String splashName = 'splash';

  static const String onboardingPath = '/onboarding';
  static const String onboardingName = 'onboarding';

  static const String loginPath = '/login';
  static const String loginName = 'login';

  static const String registerPath = '/register';
  static const String registerName = 'register';

  static const String homePath = '/home';
  static const String homeName = 'home';

  // ── Auth / app sections (tabs) ────────────────────────────────────────────
  static const String dashboardPath = '/dashboard';
  static const String dashboardName = 'dashboard';

  static const String mapPath = '/map';
  static const String mapName = 'map';

  static const String alertsPath = '/alerts';
  static const String alertsName = 'alerts';

  // ── Details ──────────────────────────────────────────────────────────────
  static const String alertDetailPath = '/alert/:alertId';
  static const String alertDetailName = 'alertDetail';

  static String alertDetailPathFor(String id) {
    return '/alert/$id';
  }

  // ── Settings ─────────────────────────────────────────────────────────────
  static const String settingsPath = '/settings';
  static const String settingsName = 'settings';

  static const String profilePath = '/profile';
  static const String profileName = 'profile';
}

// Backwards/ergonomic aliases (optional, but helps older code).
@immutable
class _AppRoutesAliases {
  const _AppRoutesAliases();
}

// ignore: unused_element
const appRoutes = _AppRoutesAliases();
