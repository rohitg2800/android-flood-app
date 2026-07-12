// lib/services/background_service.dart  Step 4.6
// Fixed:
//   • evaluate() called with positional args (not named)
//   • ExistingWorkPolicy → ExistingPeriodicWorkPolicy

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

const _kTaskName = 'floodSyncTask';
const _kTaskUniqueName = 'flood_sync_periodic';
const _kSubBoxName = 'alert_subscriptions';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await Hive.initFlutter();
      await LocalCacheService.instance.init();
      await AlertEngine.instance.init();

      final url = '${EnvConfig.backendBaseUrl}/api/live-levels';
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) return true;

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

      await LocalCacheService.instance.saveGaugeList(gauges);

      for (final g in gauges) {
        await LocalCacheService.instance
            .appendGaugeHistory(g.stationId, g.currentLevel);
      }

      if (Hive.isBoxOpen(_kSubBoxName)) {
        final box = Hive.box<AlertSubscription>(_kSubBoxName);
        final subs = box.values.toList();
        if (subs.isNotEmpty) {
          // positional args — (gauges, subscriptions)
          await AlertEngine.instance.evaluate(gauges, subs);
        }
      }

      return true;
    } catch (e) {
      debugPrint('[BG] sync error: $e');
      return true;
    }
  });
}

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
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
    debugPrint('[BG] periodic sync registered (15 min)');
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}
