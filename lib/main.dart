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

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Guard: on hot-restart the native Firebase is already alive.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }
  debugPrint('[FCM BG] ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── .env ─────────────────────────────────────────────────────────────────
  await dotenv.load(fileName: '.env').catchError((_) {});

  // ── Firebase ──────────────────────────────────────────────────────────────
  // try/catch swallows the [core/duplicate-app] exception that fires on
  // hot-restart: the Android process is still alive, Firebase native is
  // already initialised, but the Dart isolate restarts and calls initializeApp
  // a second time.  Firebase.apps.isEmpty is true from Dart's perspective
  // during a hot-restart so the guard alone is insufficient — the native
  // layer throws before Dart can check.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    // Already initialised by a previous hot-restart — safe to ignore.
    debugPrint('[Firebase] already initialised: $e');
  }
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ── Local notifications ───────────────────────────────────────────────────
  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await _localNotifications.initialize(
    const InitializationSettings(
        android: androidSettings, iOS: iosSettings),
    onDidReceiveNotificationResponse: _onNotificationTap,
  );

  // ── Module 7: Notification channels & FCM topics ─────────────────────────
  await NotificationChannelService.instance.init();
  await FcmTopicManager.instance.init();

  // ── Hive ──────────────────────────────────────────────────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(IncidentTypeAdapter());
  Hive.registerAdapter(CommunityIncidentAdapter());
  await Hive.openBox<CommunityIncident>('community_incidents');

  // ── FIX: pre-load saved locale BEFORE runApp so localeProvider starts
  //   with the correct Locale synchronously — no async race, no English flash,
  //   no null AppLocalizations on the first frame. ───────────────────────────
  final prefs = await SharedPreferences.getInstance();
  final savedLangCode = prefs.getString('app_locale') ?? 'en';

  // ── Orientation & status-bar ──────────────────────────────────────────────
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

  // ── RTDAS threshold auto-sync (Layer 3) ───────────────────────────────────
  unawaited(RtdasThresholdSyncService.instance.start());

  // ── Data engine ───────────────────────────────────────────────────────────
  DataFetchEngine.instance.start();

  // ── Active alert rules engine ─────────────────────────────────────────────
  ActiveAlertController.instance.start();

  // ── Alert → Notification bridge ───────────────────────────────────────────
  final Stream<FloodAlert> alertStream = DataFetchEngine.instance.alertStream
      .map((snapshot) => AlertEngine.instance.evaluate(snapshot))
      .expand((alerts) => alerts);
  AlertNotificationBridge.instance.start(alertStream);

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith(() => LocaleNotifier(savedLangCode)),
      ],
      child: const FloodWatchApp(),
    ),
  );
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
          case SplashScreen.route:
            return _fade(const SplashScreen());
          case OnboardingScreen.route:
            return _fade(const OnboardingScreen());
          case MainShell.route:
          case '/home':
            return _fade(const MainShell());
          case DashboardScreen.route:
            return _fade(const DashboardScreen());
          case AlertsScreen.route:
            return _fade(const AlertsScreen());
          case MonitorsScreen.route:
            return _fade(const MonitorsScreen());
          case PredictScreen.route:
            return _fade(const PredictScreen());
          case SettingsScreen.route:
            return _fade(const SettingsScreen());
          case SosScreen.route:
            return _fade(const SosScreen());
          case WeatherScreen.route:
            return _fade(const WeatherScreen());
          case RiverMonitorScreen.route:
            return _fade(const RiverMonitorScreen());
          case StateMatrixScreen.route:
            return _fade(const StateMatrixScreen());
          case ModelInfoScreen.route:
            return _fade(const ModelInfoScreen());
          case BiharRiverMapScreen.route:
            return _fade(const BiharRiverMapScreen());
          case LiveStationsScreen.route:
            return _fade(const LiveStationsScreen());
          case NewsFeedScreen.route:
            return _fade(const NewsFeedScreen());
          case MapScreen.route:
            return _fade(const MapScreen());
          case CommunityScreen.route:
            return _fade(const CommunityScreen());
          case ExportScreen.route:
            return _fade(const ExportScreen());
          case NotificationSettingsScreen.route:
            return _fade(const NotificationSettingsScreen());
          case '/city_detail':
            final cityName = settings.arguments as String? ?? '';
            return _fade(CityDetailScreen(cityName: cityName));
          case '/river_detail':
            final rdArgs = settings.arguments;
            if (rdArgs is! FloodData) return _fade(const SplashScreen());
            return _fade(RiverDetailScreen(data: rdArgs));
          case '/cwc_station':
            final cwcArgs = settings.arguments;
            if (cwcArgs is! CwcStation) return _fade(const SplashScreen());
            return _fade(CwcStationDetailScreen(station: cwcArgs));
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
