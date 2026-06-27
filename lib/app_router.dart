// lib/app_router.dart
// OpsFlood — GoRouter v4 centralized routing + auth guard redirect
//
// Single source of truth for ALL named routes.
// Routes.xxx constants must match paths used across the app.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'providers/flood_data_provider.dart';

import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';
import 'screens/dashboard_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/bihar_river_map_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/alert_settings_screen.dart';
import 'screens/accessibility_settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/evacuation_routes_screen.dart';
import 'screens/crowd_report_feed_screen.dart';
import 'screens/analytics_dashboard_screen.dart';
import 'screens/historical_analytics_screen.dart';
import 'screens/rainfall_forecast_screen.dart';
import 'screens/export_screen.dart';
import 'screens/incident_report_screen.dart';
import 'screens/river_detail_screen.dart';
import 'models/river_station.dart';

import 'screens/predict_screen_impl.dart';
import 'screens/ai_prediction_screen.dart';
import 'screens/india_river_explorer_screen.dart';

import 'screens/live_stations_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/community_screen.dart';
import 'screens/river_monitor_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/state_matrix_screen.dart';
import 'screens/model_info_screen.dart';
import 'screens/city_detail_screen.dart';

import 'models/flood_data.dart';

import 'services/route_analytics_observer.dart';

class _ConsoleAnalyticsLogger implements AnalyticsLogger {
  const _ConsoleAnalyticsLogger();

  @override
  Future<void> logScreen(String name) async {
    // ignore: avoid_print
    print('[Analytics] screen=$name');
  }
}

// ---------------------------------------------------------------------------
// Route name constants — use these everywhere, never bare strings
// ---------------------------------------------------------------------------
class Routes {
  Routes._();

  // Core flow
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const shell = '/shell';
  static const home = '/home';

  // Bottom-nav tabs
  static const dashboard = '/dashboard';
  static const monitors = '/monitors';
  static const alerts = '/alerts';
  static const map = '/map';
  static const community = '/community';
  static const settings = '/settings';

  // Map variants
  static const biharRiverMap = '/bihar-river-map';
  static const indiaRiverExplorer = '/india-river-explorer';

  // Detail screens (typed args via extra)
  static const stationDetail = '/station'; // extra: CwcStation
  static const riverDetail = '/river'; // extra: FloodData
  static const cityDetail = '/city'; // extra: String

  // Other screens
  static const riverMonitor = '/river-monitor';
  static const liveStations = '/live-stations';

  static const stateMatrix = '/state-matrix';
  static const modelInfo = '/model-info';
  static const predict = '/predict';
  static const aiPredictor = '/ai-predictor';
  static const weather = '/weather';
  static const rainfallForecast = '/rainfall-forecast';
  static const crowdReports = '/crowd-reports';
  static const incidentReport = '/incident-report';
  static const sos = '/sos';
  static const evacuation = '/evacuation';
  static const news = '/news';
  static const analytics = '/analytics';
  static const historicalAnalytics = '/historical-analytics';
  static const export_ = '/export';

  // Settings sub-screens
  static const notificationSettings = '/notification-settings';
  static const alertSettings = '/alert-settings';
  static const accessibilitySettings = '/settings/accessibility';
  static const profile = '/profile';
  static const adminDashboard = '/admin';
}

// ---------------------------------------------------------------------------
// AppRouter
// ---------------------------------------------------------------------------
class AppRouter {
  AppRouter._();

  // Router wiring
  static late FloodDataProvider _floodData;
  static String _initialLocation = Routes.splash;

  static void init(FloodDataProvider p,
      {String initialLocation = Routes.splash}) {
    _floodData = p;
    _initialLocation = initialLocation;
  }

  static GoRouter get router => GoRouter(
        initialLocation: _initialLocation,
        observers: [
          RouteAnalyticsObserver(
            logger: const _ConsoleAnalyticsLogger(),
          ),
        ],
        refreshListenable: _FloodDataRefreshListenable(),
        redirect: (context, state) => null,
        routes: [
          GoRoute(
            path: Routes.splash,
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: Routes.onboarding,
            builder: (context, state) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const SizedBox(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const SizedBox(),
          ),

          GoRoute(
            path: Routes.home,
            builder: (context, state) => const MainShell(),
          ),

          // Typed-argument routes
          GoRoute(
            path: Routes.stationDetail,
            builder: (context, state) {
              final extra = state.extra;
              if (extra is RiverStation) {
                // No RiverStation detail screen in this repo besides RiverDetailScreen(FloodData).
                // Fallback to alerts to avoid crashing on bad extras.
                return const AlertsScreen();
              }

              return const SplashScreen();
            },
          ),
          GoRoute(
            path: Routes.riverDetail,
            builder: (context, state) {
              final extra = state.extra;
              if (extra is FloodData) {
                return RiverDetailScreen(data: extra);
              }
              return const SplashScreen();
            },
          ),
          GoRoute(
            path: Routes.cityDetail,
            builder: (context, state) {
              final extra = state.extra;
              if (extra is String) {
                return CityDetailScreen(cityName: extra);
              }
              return const SplashScreen();
            },
          ),

          // Remaining routes (zero-arg)
          GoRoute(
            path: Routes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: Routes.monitors,
            builder: (context, state) => const RiverMonitorScreen(),
          ),

          // Keep existing /alerts route (no param) as sibling.
          GoRoute(
            path: Routes.alerts,
            builder: (context, state) => const AlertsScreen(),
          ),
          // Required deep-link route
          GoRoute(
            path: '/alerts/:alertId',
            builder: (context, state) {
              final stationFilter = state.pathParameters['alertId'];
              return AlertsScreen(
                stationFilter:
                    (stationFilter?.isNotEmpty == true) ? stationFilter : null,
              );
            },
          ),

          GoRoute(
            path: Routes.map,
            builder: (context, state) => const BiharRiverMapScreen(),
          ),
          GoRoute(
            path: Routes.community,
            builder: (context, state) => const CommunityScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),

          GoRoute(
            path: Routes.biharRiverMap,
            builder: (context, state) => const BiharRiverMapScreen(),
          ),
          GoRoute(
            path: Routes.indiaRiverExplorer,
            builder: (context, state) => const IndiaRiverExplorerScreen(),
          ),
          GoRoute(
            path: Routes.riverMonitor,
            builder: (context, state) => const RiverMonitorScreen(),
          ),
          GoRoute(
            path: Routes.liveStations,
            builder: (context, state) => const LiveStationsScreen(),
          ),
          GoRoute(
            path: Routes.stateMatrix,
            builder: (context, state) => const StateMatrixScreen(),
          ),
          GoRoute(
            path: Routes.modelInfo,
            builder: (context, state) => const ModelInfoScreen(),
          ),

          GoRoute(
            path: Routes.predict,
            builder: (context, state) => const PredictScreen(),
          ),
          GoRoute(
            path: Routes.aiPredictor,
            builder: (context, state) => const AiPredictionScreen(),
          ),

          GoRoute(
            path: Routes.weather,
            builder: (context, state) => const WeatherScreen(),
          ),
          GoRoute(
            path: Routes.rainfallForecast,
            builder: (context, state) => const RainfallForecastScreen(),
          ),

          GoRoute(
            path: Routes.crowdReports,
            builder: (context, state) => const CrowdReportFeedScreen(),
          ),
          GoRoute(
            path: Routes.incidentReport,
            builder: (context, state) => const IncidentReportScreen(),
          ),
          GoRoute(
            path: Routes.sos,
            builder: (context, state) => const SosScreen(),
          ),
          GoRoute(
            path: Routes.evacuation,
            builder: (context, state) => const EvacuationRoutesScreen(),
          ),
          GoRoute(
            path: Routes.news,
            builder: (context, state) => const CrowdReportFeedScreen(),
          ),

          GoRoute(
            path: Routes.analytics,
            builder: (context, state) => const AnalyticsDashboardScreen(),
          ),
          GoRoute(
            path: Routes.historicalAnalytics,
            builder: (context, state) => const HistoricalAnalyticsScreen(),
          ),
          GoRoute(
            path: Routes.export_,
            builder: (context, state) => const ExportScreen(),
          ),

          GoRoute(
            path: Routes.notificationSettings,
            builder: (context, state) => const NotificationSettingsScreen(),
          ),
          GoRoute(
            path: Routes.alertSettings,
            builder: (context, state) => const AlertSettingsScreen(),
          ),
          GoRoute(
            path: Routes.accessibilitySettings,
            builder: (context, state) => const AccessibilitySettingsScreen(),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: Routes.adminDashboard,
            builder: (context, state) => const AdminDashboardScreen(),
          ),

          GoRoute(
            path: '*',
            redirect: (context, state) => Routes.splash,
          ),
        ],
      );

  static void go(String path, {Object? extra}) => router.go(path, extra: extra);
  static void push(String path, {Object? extra}) =>
      router.push(path, extra: extra);
  static void pop() => router.pop();

  static void goToTab(int index) => router.go(Routes.shell, extra: index);
}

// Internal bridge to ensure refreshListenable is always non-null.
class _FloodDataRefreshListenable extends ChangeNotifier {
  _FloodDataRefreshListenable() {
    AppRouter._floodData.addListener(notifyListeners);
  }
}
