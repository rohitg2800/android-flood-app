import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers/flood_providers.dart';
import 'providers/theme_provider.dart';
import 'screens/alerts_screen.dart';
import 'screens/splash_screen.dart';
import 'services/fcm_service.dart';
import 'services/local_cache_service.dart';
import 'services/threshold_alert_service.dart';
import 'theme/river_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.deferFirstFrame();

  try {
    try {
      await dotenv.load(fileName: '.env', mergeWith: {});
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ .env not found — running with defaults: $e');
    }

    if (!kIsWeb) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              if (kDebugMode) debugPrint('⚠️ Firebase.initializeApp timed out');
              throw TimeoutException('Firebase init timeout');
            },
          );
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Firebase init failed (non-fatal): $e');
      }
    }

    if (!kIsWeb) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppPalette.navy0,
        systemNavigationBarIconBrightness: Brightness.light,
      ));
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

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

    await ThemeProvider().init();

    if (!kIsWeb) {
      await LocalCacheService.instance.init().catchError((e) {
        if (kDebugMode) debugPrint('⚠️ LocalCacheService.init failed: $e');
      });

      unawaited(
        FcmService.instance.init().catchError((e) {
          if (kDebugMode) debugPrint('⚠️ FcmService.init failed: $e');
        }),
      );

      unawaited(
        ThresholdAlertService.instance.start().catchError((e) {
          if (kDebugMode) debugPrint('⚠️ ThresholdAlertService.start failed: $e');
        }),
      );
    }
  } finally {
    WidgetsBinding.instance.allowFirstFrame();
  }

  runApp(const ProviderScope(child: BiharFloodWatchApp()));
}

/// Bihar Flood Watch — बिहार बाढ़ निगरानी
class BiharFloodWatchApp extends ConsumerWidget {
  const BiharFloodWatchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Bihar Flood Watch',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: RiverColors.lightTheme(),
      darkTheme: RiverColors.darkTheme(),
      home: const SplashScreen(),
      routes: {
        AlertsScreen.route: (_) => const AlertsScreen(),
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
