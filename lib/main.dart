import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads/admob_init.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'providers/flood_providers.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/alerts_screen.dart';
import 'screens/bihar_river_map_screen.dart';
import 'screens/city_detail_screen.dart';
import 'screens/india_river_explorer_screen.dart';
import 'screens/live_stations_screen.dart';
import 'screens/model_info_screen.dart';
import 'screens/monitors_screen.dart';
import 'screens/predict_screen.dart';
import 'screens/river_monitor_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/state_matrix_screen.dart';
import 'screens/weather_screen.dart';
import 'services/fcm_service.dart';
import 'services/local_cache_service.dart';
import 'services/notification_service.dart';   // #22 — topic subscriptions
import 'services/offline_cache_service.dart';  // #26 — connectivity + TTL cache
import 'services/threshold_alert_service.dart';
import 'theme/river_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  WidgetsBinding.instance.deferFirstFrame();

  try {
    // 1. Load .env
    try {
      await dotenv.load(fileName: '.env', mergeWith: {});
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️  .env not found — running with defaults: $e');
    }

    // 2. Firebase
    if (!kIsWeb) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              if (kDebugMode) debugPrint('⚠️  Firebase.initializeApp timed out — continuing without Firebase');
              throw TimeoutException('Firebase init timeout');
            },
          );
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️  Firebase init failed (non-fatal): $e');
      }
    }

    // 3. AdMob
    if (!kIsWeb) {
      try {
        await AdmobInit.initialize();
        if (kDebugMode) debugPrint('✅  AdMob initialized');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️  AdMob init failed (non-fatal): $e');
      }
    }

    // 4. System chrome
    if (!kIsWeb) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor:                    Colors.transparent,
        statusBarIconBrightness:           Brightness.light,
        systemNavigationBarColor:          AppPalette.navy0,
        systemNavigationBarIconBrightness: Brightness.light,
      ));
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    // 5. Global error handlers
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        FlutterError.presentError(details);
        debugPrint('❌ FlutterError: ${details.summary}');
      }
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (kDebugMode) debugPrint('❌ PlatformDispatcher: $error\n$stack');
      return true;
    };

    // 6. Theme + locale
    await ThemeProvider().init();

    // 7. Essential services
    if (!kIsWeb) {
      // Existing cache layer
      await LocalCacheService.instance.init().catchError((e) {
        if (kDebugMode) debugPrint('⚠️  LocalCacheService.init failed: $e');
      });

      // ── Task #26: OfflineCacheService — connectivity detection + TTL cache ──
      unawaited(
        OfflineCacheService().initialize().catchError((e) {
          if (kDebugMode) debugPrint('⚠️  OfflineCacheService.initialize failed (non-fatal): $e');
        }),
      );

      // Existing FCM setup (handles message routing)
      unawaited(
        FcmService.instance.init().catchError((e) {
          if (kDebugMode) debugPrint('⚠️  FcmService.init failed: $e');
        }),
      );

      // ── Task #22: NotificationService — local channel + topic subscriptions ──
      unawaited(
        NotificationService().initialize().catchError((e) {
          if (kDebugMode) debugPrint('⚠️  NotificationService.initialize failed (non-fatal): $e');
        }),
      );

      unawaited(
        ThresholdAlertService.instance.start().catchError((e) {
          if (kDebugMode) debugPrint('⚠️  ThresholdAlertService.start failed: $e');
        }),
      );
    }
  } finally {
    WidgetsBinding.instance.allowFirstFrame();
  }

  runApp(const ProviderScope(child: EquinoxBHApp()));
}

class EquinoxBHApp extends ConsumerWidget {
  const EquinoxBHApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Task #1: ThemeProvider already wired — themeModeProvider drives MaterialApp
    // RiverColors.lightTheme() / darkTheme() are the canonical MD3 themes
    final AppThemeMode appMode = ref.watch(themeModeProvider);
    final locale               = ref.watch(localeProvider);

    final ThemeMode flutterMode = switch (appMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light  => ThemeMode.light,
      AppThemeMode.dark   => ThemeMode.dark,
      AppThemeMode.sunset => ThemeMode.light,
      AppThemeMode.ocean  => ThemeMode.dark,
    };

    return MaterialApp(
      title:                      'EQUINOX-BH',
      debugShowCheckedModeBanner: false,
      themeMode:                  flutterMode,
      theme:                      RiverColors.lightTheme(),
      darkTheme:                  RiverColors.darkTheme(),
      locale:                     locale,
      supportedLocales:           kSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home:   const SplashScreen(),
      routes: {
        AlertsScreen.route:             (_) => const AlertsScreen(),
        '/live_stations':               (_) => const LiveStationsScreen(),
        '/weather':                     (_) => const WeatherScreen(),
        '/predict':                     (_) => const PredictScreen(),
        '/monitors':                    (_) => const MonitorsScreen(),
        '/river_monitor':               (_) => const RiverMonitorScreen(),
        '/state_matrix':                (_) => const StateMatrixScreen(),
        '/settings':                    (_) => const SettingsScreen(),
        '/model_info':                  (_) => const ModelInfoScreen(),
        '/bihar_river_map':             (_) => const BiharRiverMapScreen(),
        '/india_river_explorer':        (_) => const IndiaRiverExplorerScreen(),
        CityDetailScreen.route: (ctx) {
          final city = ModalRoute.of(ctx)!.settings.arguments as String;
          return CityDetailScreen(cityName: city);
        },
      },
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(
              mq.textScaler.scale(1.0).clamp(0.8, 1.2),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
