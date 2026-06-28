// lib/app_router.dart  nav-v4
// OpsFlood — Central App Router
//
// v4 changes (28 Jun 2026):
//   • Every non-shell route is wrapped in BackAwareRoute so Android
//     hardware back + iOS swipe-back both work and emit haptic feedback.
//   • AppBackButton widget added (lib/widgets/app_back_button.dart) —
//     any AppBar can use `leading: const AppBackButton()` for a styled
//     back button that also handles edge cases (no history → Home).

import 'package:flutter/material.dart';
import 'widgets/app_back_button.dart';

import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/main_shell.dart';
import 'screens/dashboard_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/bihar_river_map_screen.dart';

import 'screens/news_feed_screen.dart';
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
import 'screens/cwc_station_detail_screen.dart';
import 'screens/river_detail_screen.dart';
import 'screens/predict_screen.dart';
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
import 'services/befiqr_cwc_service.dart';

// ---------------------------------------------------------------------------
// Route name constants — use these everywhere, never bare strings
// ---------------------------------------------------------------------------
class Routes {
  Routes._();

  // ── Core flow
  static const splash               = '/';
  static const onboarding           = '/onboarding';
  static const shell                = '/shell';

  // ── Bottom-nav tabs
  static const dashboard            = '/dashboard';
  static const monitors             = '/monitors';
  static const alerts               = '/alerts';
  static const map                  = '/map';
  static const community            = '/community';
  static const settings             = '/settings';

  // ── Map variants
  static const biharRiverMap        = '/bihar-river-map';
  static const indiaRiverExplorer   = '/india-river-explorer';

  // ── Data / detail screens
  static const stationDetail        = '/station';
  static const riverDetail          = '/river';
  static const cityDetail           = '/city';
  static const riverMonitor         = '/river-monitor';
  static const liveStations         = '/live-stations';
  static const stateMatrix          = '/state-matrix';

  // ── Prediction / AI
  static const predict              = '/predict';
  static const aiPredictor          = '/ai-predictor';
  static const modelInfo            = '/model-info';

  // ── Weather / rain
  static const weather              = '/weather';
  static const rainfallForecast     = '/rainfall-forecast';

  // ── Community / reporting
  static const crowdReports         = '/crowd-reports';
  static const incidentReport       = '/incident-report';
  static const sos                  = '/sos';
  static const evacuation           = '/evacuation';

  // ── News / feeds
  static const news                 = '/news';

  // ── Analytics
  static const analytics            = '/analytics';
  static const historicalAnalytics  = '/historical-analytics';
  static const export_              = '/export';

  // ── Settings sub-screens
  static const notificationSettings    = '/notification-settings';
  static const alertSettings           = '/alert-settings';
  static const accessibilitySettings   = '/settings/accessibility';
  static const profile                 = '/profile';
  static const adminDashboard          = '/admin';
}

// ---------------------------------------------------------------------------
// AppRouter
// ---------------------------------------------------------------------------
class AppRouter {
  AppRouter._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  static const String initial = Routes.splash;

  /// Wraps a non-shell page in BackAwareRoute for universal back support.
  static Widget _wrap(Widget page) => BackAwareRoute(child: page);

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final uri  = Uri.parse(settings.name ?? '/');
    final path = uri.path;

    Widget page;

    switch (path) {
      // ── Core flow (no wrap — these manage their own back)
      case Routes.splash:
        page = const SplashScreen(); break;
      case Routes.onboarding:
        page = const OnboardingScreen(); break;
      case Routes.shell:
        page = MainShell(
          initialIndex: settings.arguments is int
              ? settings.arguments as int
              : 0,
        );
        break;

      // ── Bottom-nav tabs (also reachable as standalone pushes)
      case Routes.dashboard:
        page = _wrap(const DashboardScreen()); break;
      case Routes.monitors:
        page = _wrap(const RiverMonitorScreen()); break;
      case Routes.alerts:
        page = _wrap(const AlertsScreen()); break;
      case Routes.map:
        page = _wrap(const BiharRiverMapScreen()); break;
      case Routes.community:
        page = _wrap(const CommunityScreen()); break;
      case Routes.settings:
        page = _wrap(const SettingsScreen()); break;

      // ── Map variants
      case Routes.biharRiverMap:
        page = _wrap(const BiharRiverMapScreen()); break;
      case Routes.indiaRiverExplorer:
        page = _wrap(const IndiaRiverExplorerScreen()); break;

      // ── Data / detail
      case Routes.liveStations:
        page = _wrap(const LiveStationsScreen()); break;
      case Routes.stateMatrix:
        page = _wrap(const StateMatrixScreen()); break;
      case Routes.riverMonitor:
        page = _wrap(const RiverMonitorScreen()); break;
      case Routes.modelInfo:
        page = _wrap(const ModelInfoScreen()); break;

      case Routes.stationDetail: {
        final station = settings.arguments as CwcStation?;
        page = _wrap(
          station != null
              ? CwcStationDetailScreen(station: station)
              : const SplashScreen(),
        );
        break;
      }
      case Routes.riverDetail: {
        final data = settings.arguments as FloodData?;
        page = _wrap(
          data != null
              ? RiverDetailScreen(data: data)
              : const SplashScreen(),
        );
        break;
      }
      case Routes.cityDetail: {
        final cityName = settings.arguments as String?;
        page = _wrap(
          cityName != null
              ? CityDetailScreen(cityName: cityName)
              : const SplashScreen(),
        );
        break;
      }

      // ── Prediction / AI
      case Routes.predict:
        page = _wrap(const PredictScreen()); break;
      case Routes.aiPredictor:
        page = _wrap(const AiPredictionScreen()); break;

      // ── Weather / rain
      case Routes.weather:
        page = _wrap(const WeatherScreen()); break;
      case Routes.rainfallForecast:
        page = _wrap(const RainfallForecastScreen()); break;

      // ── Community / reporting
      case Routes.crowdReports:
        page = _wrap(const CrowdReportFeedScreen()); break;
      case Routes.incidentReport:
        page = _wrap(const IncidentReportScreen()); break;
      case Routes.sos:
        page = _wrap(const SosScreen()); break;
      case Routes.evacuation:
        page = _wrap(const EvacuationRoutesScreen()); break;

      // ── News
      case Routes.news:
        page = _wrap(const NewsFeedScreen()); break;

      // ── Analytics
      case Routes.analytics:
        page = _wrap(const AnalyticsDashboardScreen()); break;
      case Routes.historicalAnalytics:
        page = _wrap(const HistoricalAnalyticsScreen()); break;
      case Routes.export_:
        page = _wrap(const ExportScreen()); break;

      // ── Settings sub-screens
      case Routes.notificationSettings:
        page = _wrap(const NotificationSettingsScreen()); break;
      case Routes.alertSettings:
        page = _wrap(const AlertSettingsScreen()); break;
      case Routes.accessibilitySettings:
        page = _wrap(const AccessibilitySettingsScreen()); break;
      case Routes.profile:
        page = _wrap(const ProfileScreen()); break;
      case Routes.adminDashboard:
        page = _wrap(const AdminDashboardScreen()); break;

      default:
        page = const SplashScreen();
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => page,
    );
  }

  // --------------------------------------------------
  // Convenience helpers
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

  /// Navigate to a bottom-nav tab inside MainShell.
  static void goToTab(int index) {
    push(Routes.shell, arguments: index);
  }
}
