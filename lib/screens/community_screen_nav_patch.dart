// lib/screens/community_screen_nav_patch.dart
// Patch note: community_screen.dart internally uses Navigator.pushNamed.
// Ensure these routes resolve correctly via AppRouter:
//   Routes.incidentReport  -> IncidentReportScreen
//   Routes.crowdReports    -> CrowdReportFeedScreen
//   Routes.sos             -> SosScreen
//   Routes.evacuation      -> EvacuationRoutesScreen
// All are now registered in app_router.dart nav-v1.
// No code changes needed to community_screen.dart itself.
