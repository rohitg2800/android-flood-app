// lib/services/background_service.dart  Step 4.5
// Completes the WorkManager stub with a real 15-minute periodic sync task.
// On each run:
//   1. Fetches /api/live-levels
//   2. Saves result to LocalCacheService (Hive)
//   3. Appends level history for each station
//   4. Evaluates AlertEngine against stored subscriptions
//   5. Fires local notifications if thresholds crossed

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/flood_data.dart';
import '../models/alert_subscription.dart';
import '../config/env_config.dart';
import 'local_cache_service.dart';
import 'alert_engine.dart';

const _kTaskName       = 'floodSyncTask';
const _kTaskUniqueName = 'flood_sync_periodic';
const _kSubBoxName     = 'alert_subscriptions';

// ── Top-level callback (required by WorkManager) ────────────────────────────

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await Hive.initFlutter();
      await LocalCacheService.instance.init();
      await AlertEngine.instance.init();

      // 1. Fetch live levels
      final url  = '${EnvConfig.backendBaseUrl}/api/live-levels';
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) return true; // non-fatal

      final decoded = jsonDecode(resp.body);
      List<dynamic> list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map && decoded.containsKey('data')) {
        list = decoded['data'] as List<dynamic>;
      } else {
        return true;
      }

      final gauges = list
          .map((e) => FloodData.fromJson(e as Map<String, dynamic>))
          .toList();

      // 2. Persist to Hive
      await LocalCacheService.instance.saveGaugeList(gauges);

      // 3. Append history
      for (final g in gauges) {
        await LocalCacheService.instance
            .appendGaugeHistory(g.stationId, g.currentLevel);
      }

      // 4 & 5. Evaluate alerts
      if (Hive.isBoxOpen(_kSubBoxName)) {
        final box  = Hive.box<AlertSubscription>(_kSubBoxName);
        final subs = box.values.toList();
        if (subs.isNotEmpty) {
          await AlertEngine.instance.evaluate(
            gauges:        gauges,
            subscriptions: subs,
          );
        }
      }

      return true;
    } catch (e) {
      debugPrint('[BG] sync error: $e');
      return true; // always return true to avoid WorkManager retry storms
    }
  });
}

// ── Registration helper (call from main.dart) ────────────────────────────────

class BackgroundSyncService {
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  static Future<void> registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      _kTaskUniqueName,
      _kTaskName,
      frequency:   const Duration(minutes: 15),
      constraints: Constraints(
        networkType:          NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy:      BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
    debugPrint('[BG] periodic sync registered (15 min)');
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}
