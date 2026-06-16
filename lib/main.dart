// lib/main.dart
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart' as pv;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'models/flood_data.dart';
import 'models/community_incident.dart';
import 'models/river_station.dart';
import 'providers/flood_data_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';
import 'screens/dashboard_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/river_monitor_screen.dart';
import 'screens/predict_screen.dart';
import 'screens/city_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/river_detail_screen.dart';
import 'screens/state_matrix_screen.dart';
import 'screens/model_info_screen.dart';
import 'screens/bihar_river_map_screen.dart';
import 'screens/live_stations_screen.dart';
import 'screens/news_feed_screen.dart';

import 'screens/export_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/incident_report_screen.dart';
import 'screens/crowd_report_feed_screen.dart';
import 'screens/evacuation_routes_screen.dart';
import 'screens/ai_prediction_screen.dart';
import 'screens/india_river_explorer_screen.dart';
import 'screens/rainfall_forecast_screen.dart';
import 'screens/historical_analytics_screen.dart';
import 'screens/analytics_dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/community_screen.dart';
import 'screens/cwc_station_detail_screen.dart';
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
import 'app_router.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }
  debugPrint('[FCM BG] ${message.notification?.title}');
}

String _parseStation(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final stripped = raw.replaceAll(
      RegExp(r'^[\u{1F600}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\s]+',
          unicode: true),
      '');
  final colonIdx = stripped.indexOf(':');
  if (colonIdx > 0) {
    final before = stripped.substring(0, colonIdx).trim().toUpperCase();
    final after  = stripped.substring(colonIdx + 1).trim();
    const alertKeywords = {
      'EMERGENCY', 'CRITICAL', 'WARNING', 'ADVISORY', 'INFO', 'DANGER', 'ALERT',
    };
    if (alertKeywords.contains(before)) return after;
    final afterUpper = after.toUpperCase();
    if (alertKeywords.any((k) => afterUpper.contains(k))) return before;
    return before.length <= after.length ? before : after;
  }
  return stripped.trim();
}

void _navigateFromNotification({
  String? payload,
  String? title,
  String? body,
}) {
  final nav = navigatorKey.currentState;
  if (nav == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateFromNotification(payload: payload, title: title, body: body);
    });
    return;
  }
  debugPrint('[Notif] navigate  payload=$payload  title=$title');
  String stationName = '';
  if (payload != null && payload.isNotEmpty) {
    final parts = payload.split('_');
    if (parts.length >= 2) {
      final severityWords = {'danger', 'warning', 'critical', 'emergency', 'info', 'advisory'};
      final stationParts = <String>[];
      for (final p in parts) {
        if (severityWords.contains(p.toLowerCase())) break;
        if (RegExp(r'^\d{10,}$').hasMatch(p)) break;
        stationParts.add(p);
      }
      stationName = stationParts.join(' ').trim();
    }
    if (stationName.isEmpty && !payload.contains('_')) {
      stationName = payload.trim();
    }
  }
  if (stationName.isEmpty) stationName = _parseStation(title);
  debugPrint('[Notif] resolved station: "$stationName"');
  if (stationName.isNotEmpty) {
    nav.pushNamed(Routes.alerts, arguments: stationName);
  } else {
    nav.pushNamed(Routes.alerts);
  }
}

void _onNotificationTap(NotificationResponse response) {
  debugPrint('[Notif] tapped payload=${response.payload}');
  _navigateFromNotification(payload: response.payload);
}

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      }
    } catch (e) {
      debugPrint('[Firebase] already initialised: $e');
    }
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kReleaseMode) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } else {
        FlutterError.presentError(details);
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kReleaseMode) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      return true;
    };
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await dotenv.load(fileName: '.env').catchError((_) {});
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
      // ── Riverpod scope (ref.watch providers) ────────────────────────────
      ProviderScope(
        overrides: [
          localeProvider.overrideWith(() => LocaleNotifier(savedLangCode)),
        ],
        // ── provider package: FloodDataProvider for Consumer<FloodDataProvider> ──
        child: pv.MultiProvider(
          providers: [
            pv.ChangeNotifierProvider<FloodDataProvider>(
              // FloodDataProvider constructor already calls _load() internally
              create: (_) => FloodDataProvider(),
            ),
          ],
          child: const FloodWatchApp(),
        ),
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
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
            '[FCM] launched from notification: ${initialMessage.notification?.title}');
        _navigateFromNotification(
          payload: initialMessage.data['alertId'] as String?,
          title:   initialMessage.notification?.title,
          body:    initialMessage.notification?.body,
        );
      }
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
            '[FCM] onMessageOpenedApp: ${message.notification?.title}');
        _navigateFromNotification(
          payload: message.data['alertId'] as String?,
          title:   message.notification?.title,
          body:    message.notification?.body,
        );
      });
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notif = message.notification;
        if (notif == null) return;
        debugPrint('[FCM FG] ${notif.title}');
        _localNotifications.show(
          message.hashCode & 0x7FFFFFFF,
          notif.title,
          notif.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _severityChannelFromData(message.data),
              'Flood Alerts',
              importance: Importance.max,
              priority:   Priority.high,
              icon:       '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data['alertId'] as String? ?? notif.title,
        );
      });
      unawaited(NotificationChannelService.instance.init());
      unawaited(FcmTopicManager.instance.init());
      unawaited(RtdasThresholdSyncService.instance.start());
      DataFetchEngine.instance.start();
      ActiveAlertController.instance.start();

      final Stream<FloodAlert> alertStream = DataFetchEngine
          .instance
          .snapshotStream
          .expand((snapshot) {
            final List<RiverStation> stations = snapshot.stations.map((d) => RiverStation(
              city:    d.stationName,
              state:   d.state,
              river:   d.river,
              station: d.stationId,
              current: d.currentLevel,
              warning: d.warningLevel,
              danger:  d.dangerLevel,
              hfl:     d.hfl,
              lat:     d.latitude,
              lon:     d.longitude,
              isLive:  d.isLive,
            )).toList();
            return AlertEngine.instance.evaluateMerged(stations);
          });
      AlertNotificationBridge.instance.start(alertStream);
    });
  }, (Object error, StackTrace stack) {
    debugPrint('[CRASH ZONE] $error\n$stack');
    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

String _severityChannelFromData(Map<String, dynamic> data) {
  final severity = (data['severity'] as String? ?? '').toLowerCase();
  if (severity == 'emergency') return 'flood_emergency';
  if (severity == 'critical')  return 'flood_critical';
  if (severity == 'warning')   return 'flood_warning';
  return 'flood_info';
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
      navigatorKey:               navigatorKey,
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
            return _fade(const SplashScreen());
          case Routes.onboarding:
            return _fade(const OnboardingScreen());
          case Routes.shell:
            return _fade(const MainShell());
          case Routes.dashboard:
            return _fade(const DashboardScreen());
          case Routes.alerts: {
            final stationFilter = settings.arguments as String?;
            return _fade(AlertsScreen(stationFilter: stationFilter));
          }
          case Routes.monitors:
            return _fade(const RiverMonitorScreen());
          case Routes.predict:
            return _fade(const PredictScreen());
          case Routes.settings:
            return _fade(const SettingsScreen());
          case Routes.sos:
            return _fade(const SosScreen());
          case Routes.evacuation:
            return _fade(const EvacuationRoutesScreen());
          case Routes.weather:
            return _fade(const WeatherScreen());
          case Routes.riverMonitor:
            return _fade(const RiverMonitorScreen());
          case Routes.stateMatrix:
            return _fade(const StateMatrixScreen());
          case Routes.modelInfo:
            return _fade(const ModelInfoScreen());
          case Routes.biharRiverMap:
            return _fade(const BiharRiverMapScreen());
          case Routes.liveStations:
            return _fade(const LiveStationsScreen());
          case Routes.news:
            return _fade(const NewsFeedScreen());
          case Routes.map:
            return _fade(const BiharRiverMapScreen());
          case Routes.community:
            return _fade(const CommunityScreen());
          case Routes.export_:
            return _fade(const ExportScreen());
          case Routes.notificationSettings:
            return _fade(const NotificationSettingsScreen());
          case Routes.incidentReport:
            return _fade(const IncidentReportScreen());
          case Routes.crowdReports:
            return _fade(const CrowdReportFeedScreen());
          case Routes.aiPredictor:
            return _fade(const AiPredictionScreen());
          case Routes.indiaRiverExplorer:
            return _fade(const IndiaRiverExplorerScreen());
          case Routes.rainfallForecast:
            return _fade(const RainfallForecastScreen());
          case Routes.historicalAnalytics:
            return _fade(const HistoricalAnalyticsScreen());
          case Routes.analytics:
            return _fade(const AnalyticsDashboardScreen());
          case Routes.profile:
            return _fade(const ProfileScreen());
          case Routes.adminDashboard:
            return _fade(const AdminDashboardScreen());
          case Routes.cityDetail: {
            final cityName = settings.arguments as String? ?? '';
            return _fade(CityDetailScreen(cityName: cityName));
          }
          case Routes.riverDetail: {
            final rdArgs = settings.arguments;
            if (rdArgs is! FloodData) return _fade(const SplashScreen());
            return _fade(RiverDetailScreen(data: rdArgs));
          }
          case Routes.stationDetail: {
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
