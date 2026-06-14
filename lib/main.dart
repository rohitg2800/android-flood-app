// lib/main.dart
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'models/flood_data.dart';
import 'models/community_incident.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';
import 'screens/dashboard_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/monitors_screen.dart';
import 'screens/predict_screen.dart';
import 'screens/city_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/river_monitor_screen.dart';
import 'screens/river_detail_screen.dart';
import 'screens/state_matrix_screen.dart';
import 'screens/model_info_screen.dart';
import 'screens/bihar_river_map_screen.dart';
import 'screens/cwc_station_detail_screen.dart';
import 'screens/community_screen.dart';
import 'screens/live_stations_screen.dart';
import 'screens/news_feed_screen.dart';
import 'screens/map_screen.dart';
import 'screens/export_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/incident_report_screen.dart';
import 'screens/crowd_report_feed_screen.dart';
import 'screens/evacuation_routes_screen.dart'; // ← already imported
// ── Phase 9 ──────────────────────────────────────────────────────────────────
import 'screens/ai_prediction_screen.dart';
// ── Phase 10 ─────────────────────────────────────────────────────────────────
import 'screens/india_river_explorer_screen.dart';
// ── Analytics / Forecast ─────────────────────────────────────────────────────
import 'screens/rainfall_forecast_screen.dart';
import 'screens/historical_analytics_screen.dart';
import 'screens/analytics_dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'services/befiqr_cwc_service.dart';
import 'services/notification_channel_service.dart';
import 'services/fcm_topic_manager.dart';
import 'services/alert_notification_bridge.dart';
import 'services/alert_engine.dart';
import 'services/rtdas_threshold_sync_service.dart';
import 'services/active_alert_controller.dart';
import 'theme/river_theme.dart';
import 'theme/robotic_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'services/data_fetch_engine.dart';
import 'app_router.dart'; // Routes constants

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }
  debugPrint('[FCM BG] ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env').catchError((_) {});

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    debugPrint('[Firebase] already initialised: $e');
  }
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Hive.initFlutter();
  Hive.registerAdapter(IncidentTypeAdapter());
  Hive.registerAdapter(CommunityIncidentAdapter());
  await Hive.openBox<CommunityIncident>('community_incidents');

  final prefs = await SharedPreferences.getInstance();
  final savedLangCode = prefs.getString('app_locale') ?? 'en';

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith(() => LocaleNotifier(savedLangCode)),
      ],
      child: const FloodWatchApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    unawaited(NotificationChannelService.instance.init());
    unawaited(FcmTopicManager.instance.init());
    unawaited(RtdasThresholdSyncService.instance.start());

    DataFetchEngine.instance.start();
    ActiveAlertController.instance.start();

    final Stream<FloodAlert> alertStream = DataFetchEngine.instance.alertStream
        .map((snapshot) => AlertEngine.instance.evaluate(snapshot))
        .expand((alerts) => alerts);
    AlertNotificationBridge.instance.start(alertStream);
  });
}

void _onNotificationTap(NotificationResponse response) {
  final payload = response.payload ?? '';
  debugPrint('[Notif] tapped: $payload');
}

class FloodWatchApp extends ConsumerWidget {
  const FloodWatchApp({super.key});

  static ThemeData _themeFor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:        return RiverColors.lightTheme();
      case AppThemeMode.dark:         return RiverColors.darkTheme();
      case AppThemeMode.sunset:       return RiverColors.sunsetTheme();
      case AppThemeMode.ocean:        return RiverColors.oceanTheme();
      case AppThemeMode.roboticDark:  return const RoboticTheme(isDark: true).toThemeData();
      case AppThemeMode.roboticLight: return const RoboticTheme(isDark: false).toThemeData();
      case AppThemeMode.system:       return RiverColors.darkTheme();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode          = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);
    final locale        = ref.watch(localeProvider);

    final ThemeData lightSlot;
    final ThemeData darkSlot;

    if (mode == AppThemeMode.system) {
      lightSlot = RiverColors.lightTheme();
      darkSlot  = RiverColors.darkTheme();
    } else {
      final t = _themeFor(mode);
      lightSlot = t;
      darkSlot  = t;
    }

    return MaterialApp(
      title:                      'FloodWatch',
      debugShowCheckedModeBanner: false,
      theme:                      lightSlot,
      darkTheme:                  darkSlot,
      themeMode:                  themeNotifier.flutterMode,
      locale:                     locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale == null) return const Locale('en');
        for (final sl in supportedLocales) {
          if (sl.languageCode == deviceLocale.languageCode) return sl;
        }
        return const Locale('en');
      },
      initialRoute: SplashScreen.route,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case Routes.splash:
          case SplashScreen.route:
            return _fade(const SplashScreen());
          case Routes.onboarding:
          case OnboardingScreen.route:
            return _fade(const OnboardingScreen());
          case Routes.shell:
          case '/home':
            return _fade(const MainShell());
          case Routes.dashboard:
          case DashboardScreen.route:
            return _fade(const DashboardScreen());
          case Routes.alerts:
          case AlertsScreen.route:
            return _fade(const AlertsScreen());
          case Routes.monitors:
          case MonitorsScreen.route:
            return _fade(const MonitorsScreen());
          case Routes.predict:
          case PredictScreen.route:
            return _fade(const PredictScreen());
          case Routes.settings:
          case SettingsScreen.route:
            return _fade(const SettingsScreen());
          case Routes.sos:
          case SosScreen.route:
            return _fade(const SosScreen());
          // ── FIX: evacuation was missing from main.dart onGenerateRoute ──
          // Routes.evacuation = '/evacuation'
          // Old EvacuationRoutesScreen.route was '/evacuation-routes' (mismatch!)
          // Now both are '/evacuation'. Both cases kept for safety.
          case Routes.evacuation:          // '/evacuation'  ← the one called everywhere
          case '/evacuation-routes':       // legacy fallback
            return _fade(const EvacuationRoutesScreen());
          case Routes.weather:
          case WeatherScreen.route:
            return _fade(const WeatherScreen());
          case Routes.riverMonitor:
          case RiverMonitorScreen.route:
            return _fade(const RiverMonitorScreen());
          case Routes.stateMatrix:
          case StateMatrixScreen.route:
            return _fade(const StateMatrixScreen());
          case Routes.modelInfo:
          case ModelInfoScreen.route:
            return _fade(const ModelInfoScreen());
          case Routes.biharRiverMap:
          case BiharRiverMapScreen.route:
            return _fade(const BiharRiverMapScreen());
          case Routes.liveStations:
          case LiveStationsScreen.route:
            return _fade(const LiveStationsScreen());
          case Routes.news:
          case NewsFeedScreen.route:
            return _fade(const NewsFeedScreen());
          case Routes.map:
          case MapScreen.route:
            return _fade(const MapScreen());
          case Routes.community:
          case CommunityScreen.route:
            return _fade(const CommunityScreen());
          case Routes.export_:
          case ExportScreen.route:
            return _fade(const ExportScreen());
          case Routes.notificationSettings:
          case NotificationSettingsScreen.route:
            return _fade(const NotificationSettingsScreen());
          case Routes.incidentReport:
          case IncidentReportScreen.route:
            return _fade(const IncidentReportScreen());
          case Routes.crowdReports:
          case CrowdReportFeedScreen.route:
            return _fade(const CrowdReportFeedScreen());
          case Routes.aiPredictor:
          case AiPredictionScreen.route:
            return _fade(const AiPredictionScreen());
          case Routes.indiaRiverExplorer:
          case IndiaRiverExplorerScreen.route:
            return _fade(const IndiaRiverExplorerScreen());
          case Routes.rainfallForecast:
          case RainfallForecastScreen.route:
            return _fade(const RainfallForecastScreen());
          case Routes.historicalAnalytics:
          case HistoricalAnalyticsScreen.route:
            return _fade(const HistoricalAnalyticsScreen());
          case Routes.analytics:
          case AnalyticsDashboardScreen.route:
            return _fade(const AnalyticsDashboardScreen());
          case Routes.profile:
          case ProfileScreen.route:
            return _fade(const ProfileScreen());
          case Routes.adminDashboard:
          case AdminDashboardScreen.route:
            return _fade(const AdminDashboardScreen());
          case Routes.cityDetail:
          case '/city_detail': {
            final cityName = settings.arguments as String? ?? '';
            return _fade(CityDetailScreen(cityName: cityName));
          }
          case Routes.riverDetail:
          case '/river_detail': {
            final rdArgs = settings.arguments;
            if (rdArgs is! FloodData) return _fade(const SplashScreen());
            return _fade(RiverDetailScreen(data: rdArgs));
          }
          case Routes.stationDetail:
          case '/cwc_station': {
            final cwcArgs = settings.arguments;
            if (cwcArgs is! CwcStation) return _fade(const SplashScreen());
            return _fade(CwcStationDetailScreen(station: cwcArgs));
          }
          default:
            return _fade(const SplashScreen());
        }
      },
    );
  }

  PageRoute<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder:        (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      );
}
