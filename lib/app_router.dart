// lib/app_router.dart
// OpsFlood — Module 15: Central App Router
//
// Single source of truth for all named routes.
// Usage in MaterialApp:
//
//   MaterialApp(
//     navigatorKey: AppRouter.navigatorKey,
//     onGenerateRoute: AppRouter.onGenerateRoute,
//     initialRoute: AppRouter.initial,
//   )

import 'package:flutter/material.dart';

import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/main_shell.dart';
import 'screens/dashboard_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/bihar_river_map_screen.dart';
import 'screens/news_feed_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/evacuation_routes_screen.dart';
import 'screens/crowd_report_feed_screen.dart';
import 'screens/analytics_dashboard_screen.dart';
import 'screens/rainfall_forecast_screen.dart';
import 'screens/export_screen.dart';
import 'screens/incident_report_screen.dart';
import 'screens/cwc_station_detail_screen.dart';
import 'screens/river_detail_screen.dart';
import 'screens/historical_analytics_screen.dart';
import 'screens/predict_screen.dart';
import 'models/flood_data.dart';
import 'services/befiqr_cwc_service.dart';

// ---------------------------------------------------------------------------
// Route names (const strings — use these everywhere)
// ---------------------------------------------------------------------------

class Routes {
  Routes._();

  static const splash              = '/';
  static const onboarding          = '/onboarding';
  static const shell               = '/shell';
  static const dashboard           = '/dashboard';
  static const alerts              = '/alerts';
  static const map                 = '/map';
  static const news                = '/news';
  static const settings            = '/settings';
  static const notificationSettings = '/notification-settings';
  static const profile             = '/profile';
  static const sos                 = '/sos';
  static const evacuation          = '/evacuation';
  static const crowdReports        = '/crowd-reports';
  static const analytics           = '/analytics';
  static const rainfallForecast    = '/rainfall-forecast';
  static const export_             = '/export';
  static const incidentReport      = '/incident-report';
  static const stationDetail       = '/station';
  static const riverDetail         = '/river';
  static const historicalAnalytics = '/historical-analytics';
  static const predict             = '/predict';
}

// ---------------------------------------------------------------------------
// AppRouter
// ---------------------------------------------------------------------------

class AppRouter {
  AppRouter._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Initial route: SplashScreen decides onboarding vs shell.
  static const String initial = Routes.splash;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final uri  = Uri.parse(settings.name ?? '/');
    final path = uri.path;

    final Widget page = switch (path) {
      Routes.splash    => const SplashScreen(),
      Routes.onboarding => const OnboardingScreen(),
      // MainShell has no initialTab param — use IndexedStack internally
      Routes.shell     => const MainShell(),
      Routes.dashboard => const DashboardScreen(),
      Routes.alerts    => const AlertsScreen(),
      Routes.map       => const BiharRiverMapScreen(),
      Routes.news      => const NewsFeedScreen(),
      Routes.settings  => const SettingsScreen(),
      Routes.notificationSettings =>
          const NotificationSettingsScreen(),
      Routes.profile   => const ProfileScreen(),
      Routes.sos       => const SosScreen(),
      Routes.evacuation => const EvacuationRoutesScreen(),
      // CrowdReportFeedScreen exists but has no class body — use a stub
      Routes.crowdReports => const Scaffold(
          body: Center(child: Text('Crowd Reports coming soon')),
        ),
      Routes.analytics => const AnalyticsDashboardScreen(),
      Routes.rainfallForecast =>
          const RainfallForecastScreen(),
      Routes.export_   => const ExportScreen(),
      Routes.incidentReport =>
          const IncidentReportScreen(),
      Routes.historicalAnalytics =>
          const HistoricalAnalyticsScreen(),
      Routes.predict   => const PredictScreen(),

      // /station — expects CwcStation in settings.arguments
      Routes.stationDetail => () {
          final station = settings.arguments as CwcStation?;
          if (station == null) return const SplashScreen();
          return CwcStationDetailScreen(station: station);
        }(),

      // /river — expects FloodData in settings.arguments
      Routes.riverDetail => () {
          final data = settings.arguments as FloodData?;
          if (data == null) return const SplashScreen();
          return RiverDetailScreen(data: data);
        }(),

      _ => const SplashScreen(),
    };

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => page,
    );
  }

  // --------------------------------------------------
  // Convenience push helpers
  // --------------------------------------------------

  static Future<T?> push<T>(String route, {Object? arguments}) =>
      navigatorKey.currentState!.pushNamed<T>(route, arguments: arguments);

  static Future<T?> pushReplacement<T>(String route, {Object? arguments}) =>
      navigatorKey.currentState!.pushReplacementNamed<T, dynamic>(
          route, arguments: arguments);

  static void pop<T>([T? result]) =>
      navigatorKey.currentState?.pop(result);

  static void popUntilRoot() =>
      navigatorKey.currentState?.popUntil((r) => r.isFirst);
}
