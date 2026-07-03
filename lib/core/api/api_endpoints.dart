class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = 'https://your-api-domain.com/api/v1';

  // ── Pump Stations ──────────────────────────────────────────────
  static const String pumpStations = '/pump-stations';
  static String pumpStationById(String id) => '/pump-stations/$id';
  static String pumpStationStatus(String id) => '/pump-stations/$id/status';
  static String reportPumpIssue(String id) => '/pump-stations/$id/issues';

  // ── Flood Alerts ───────────────────────────────────────────────
  static const String floodAlerts = '/flood-alerts';
  static String floodAlertById(String id) => '/flood-alerts/$id';
  static const String activeAlerts = '/flood-alerts/active';

  // ── Community Incidents ────────────────────────────────────────
  static const String communityIncidents = '/community-incidents';
  static String incidentById(String id) => '/community-incidents/$id';
  static const String reportIncident = '/community-incidents/report';

  // ── Accessibility ──────────────────────────────────────────────
  static const String accessibilitySettings = '/accessibility/settings';
  static const String updateAccessibility = '/accessibility/settings';

  // ── User ───────────────────────────────────────────────────────
  static const String userProfile = '/user/profile';
  static const String userPreferences = '/user/preferences';
  static const String updatePreferences = '/user/preferences';

  // ── Weather ────────────────────────────────────────────────────
  static const String weatherCurrent = '/weather/current';
  static const String weatherForecast = '/weather/forecast';

  // ── Notifications ──────────────────────────────────────────────
  static const String notifications = '/notifications';
  static const String markNotificationRead = '/notifications/{id}/read';
  static const String registerFcmToken = '/notifications/fcm-token';
}
