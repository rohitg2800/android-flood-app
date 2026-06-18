// lib/app_router.dart  nav-v2
// OpsFlood — Central App Router
//
// Single source of truth for ALL named routes.
// Every screen in lib/screens/ is registered here.
// Use Routes.xxx constants everywhere — never hard-code strings.

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
  static const map                  = '/map';         // alias → BiharRiverMapScreen (bottom-nav tab)
  static const community            = '/community';
  static const settings             = '/settings';

  // ── Map variants
  static const biharRiverMap        = '/bihar-river-map';      // canonical deep-link
  static const indiaRiverExplorer   = '/india-river-explorer';

  // ── Data / detail screens
  static const stationDetail        = '/station';       // arg: CwcStation
  static const riverDetail          = '/river';         // arg: FloodData
  static const cityDetail           = '/city';          // arg: String cityName
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

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final uri  = Uri.parse(settings.name ?? '/');
    final path = uri.path;

    Widget page;

    switch (path) {
      // ── Core flow
      case Routes.splash:
        page = const SplashScreen(); break;
      case Routes.onboarding:
        page = const OnboardingScreen(); break;
      case Routes.shell:
        page = const MainShell(); break;

      // ── Bottom-nav tabs (also reachable as standalone pushes)
      case Routes.dashboard:
        page = const DashboardScreen(); break;
      case Routes.monitors:
        page = const RiverMonitorScreen(); break;
      case Routes.alerts:
        page = const AlertsScreen(); break;
      case Routes.map:
        page = const BiharRiverMapScreen(); break;
      case Routes.community:
        page = const CommunityScreen(); break;
      case Routes.settings:
        page = const SettingsScreen(); break;

      // ── Map variants
      case Routes.biharRiverMap:
        page = const BiharRiverMapScreen(); break;
      case Routes.indiaRiverExplorer:
        page = const IndiaRiverExplorerScreen(); break;

      // ── Data / detail
      case Routes.liveStations:
        page = const LiveStationsScreen(); break;
      case Routes.stateMatrix:
        page = const StateMatrixScreen(); break;
      case Routes.riverMonitor:
        page = const RiverMonitorScreen(); break;
      case Routes.modelInfo:
        page = const ModelInfoScreen(); break;

      case Routes.stationDetail: {
        final station = settings.arguments as CwcStation?;
        page = station != null
            ? CwcStationDetailScreen(station: station)
            : const SplashScreen();
        break;
      }
      case Routes.riverDetail: {
        final data = settings.arguments as FloodData?;
        page = data != null
            ? RiverDetailScreen(data: data)
            : const SplashScreen();
        break;
      }
      case Routes.cityDetail: {
        final cityName = settings.arguments as String?;
        page = cityName != null
            ? CityDetailScreen(cityName: cityName)
            : const SplashScreen();
        break;
      }

      // ── Prediction / AI
      case Routes.predict:
        page = const PredictScreen(); break;
      case Routes.aiPredictor:
        page = const AiPredictionScreen(); break;

      // ── Weather / rain
      case Routes.weather:
        page = const WeatherScreen(); break;
      case Routes.rainfallForecast:
        page = const RainfallForecastScreen(); break;

      // ── Community / reporting
      case Routes.crowdReports:
        page = const CrowdReportFeedScreen(); break;
      case Routes.incidentReport:
        page = const IncidentReportScreen(); break;
      case Routes.sos:
        page = const SosScreen(); break;
      case Routes.evacuation:
        page = const EvacuationRoutesScreen(); break;

      // ── News
      case Routes.news:
        page = const NewsFeedScreen(); break;

      // ── Analytics
      case Routes.analytics:
        page = const AnalyticsDashboardScreen(); break;
      case Routes.historicalAnalytics:
        page = const HistoricalAnalyticsScreen(); break;
      case Routes.export_:
        page = const ExportScreen(); break;

      // ── Settings sub-screens
      case Routes.notificationSettings:
        page = const NotificationSettingsScreen(); break;
      case Routes.alertSettings:
        page = const AlertSettingsScreen(); break;
      case Routes.accessibilitySettings:
        page = const AccessibilitySettingsScreen(); break;
      case Routes.profile:
        page = const ProfileScreen(); break;
      case Routes.adminDashboard:
        page = const AdminDashboardScreen(); break;

      default:
        page = const SplashScreen();
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => page,
    );
  }

  // --------------------------------------------------
  // Convenience helpers — usable anywhere with AppRouter.push(Routes.xxx)
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

  // Go to a bottom-nav tab inside MainShell by pushing shell with a tabIndex
  // argument. MainShell reads this in initState if needed, or call
  // AppRouter.push(Routes.shell) and rely on IndexedStack keepAlive.
  static void goToTab(int index) {
    push(Routes.shell, arguments: index);
  }
}
