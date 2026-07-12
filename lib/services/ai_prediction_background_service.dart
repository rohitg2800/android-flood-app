// lib/services/ai_prediction_background_service.dart
// Fixed: ExistingWorkPolicy → ExistingPeriodicWorkPolicy
library;

import '../config/app_config.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'ops_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const _kTaskName = 'aiPredictionPoll';
const _kTaskUniqueName = 'ai_prediction_periodic';
const _kChannelId = 'ai_flood_bg';
const _kChannelName = 'AI Flood Monitor';
const _kAlertBaseId = 9100;
const _kPrefKey = 'ai_bg_last_severity';

@pragma('vm:entry-point')
void aiPredictionCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await _initNotifications();
      await _pollAll();
    } catch (e) {
      debugPrint('[AiBg] poll error: $e');
    }
    return true;
  });
}

class AiPredictionBgService {
  AiPredictionBgService._();

  static const int kPollIntervalMinutes = 30;

  static Future<void> initialise() async {
    await _initNotifications();
    await Workmanager().initialize(
      aiPredictionCallbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  static Future<void> start() async {
    await Workmanager().registerPeriodicTask(
      _kTaskUniqueName,
      _kTaskName,
      frequency: Duration(minutes: kPollIntervalMinutes),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
    debugPrint('[AiBg] periodic poll registered ($kPollIntervalMinutes min)');
  }

  static Future<void> stop() async {
    await Workmanager().cancelByUniqueName(_kTaskUniqueName);
    debugPrint('[AiBg] periodic poll cancelled');
  }

  static Future<bool> get isRunning async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kPrefKey);
  }
}

final _notif = FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await _notif.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );
  const channel = AndroidNotificationChannel(
    _kChannelId,
    _kChannelName,
    description: 'Live AI flood severity alerts',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );
  await _notif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> _showAlert({
  required int id,
  required String title,
  required String body,
  bool highPriority = false,
}) async {
  await _notif.show(
    id,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        importance:
            highPriority ? Importance.high : Importance.defaultImportance,
        priority: highPriority ? Priority.high : Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    ),
  );
}

const List<String> _kSeedStations = [
  'Gandhighat',
  'Hathidah',
  'Digha Ghat',
  'Gandhi Setu',
  'Munger',
  'Bhagalpur',
  'Sultanganj',
  'Kahalgaon',
  'Farakka',
  'Birpur',
  'Baltara',
  'Rosera',
  'Benibad',
  'Hayaghat',
  'Khagaria',
  'Minapur',
  'Lalganj',
  'Bettiah',
  'Bagaha',
  'Valmikinagar',
  'Triveni',
  'Banmankhi',
  'Purnea',
  'Forbesganj',
  'Araria',
  'Sitamarhi',
  'Muzaffarpur',
  'Motihari',
  'Darbhanga',
  'Samastipur',
  'Patna',
];

Future<void> _pollAll() async {
  final prefs = await SharedPreferences.getInstance();
  final Map<String, String> lastSeverity = Map<String, String>.from(
    jsonDecode(prefs.getString(_kPrefKey) ?? '{}') as Map,
  );

  List<String> stations = await _fetchLiveStations();
  if (stations.isEmpty) stations = _kSeedStations;

  int alertsFired = 0;
  for (int i = 0; i < stations.length; i++) {
    final site = stations[i];
    try {
      final pred = await _fetchPrediction(site);
      if (pred == null) {
        debugPrint('[AiBg] no prediction for $site — skipping');
        continue;
      }

      final newSev = _severity(pred['currentLevel']!, pred['dangerLevel']!);
      final oldSev = lastSeverity[site];

      if (oldSev == null || _sevRank(newSev) > _sevRank(oldSev)) {
        if (newSev != 'LOW') {
          final gap = (pred['dangerLevel']! - pred['currentLevel']!).abs();
          await _showAlert(
            id: _kAlertBaseId + i,
            title: '\u26a0 $site \u2014 $newSev',
            body: '${_sevEmoji(newSev)} '
                '${oldSev == null ? 'First reading' : 'Escalated $oldSev \u2192 $newSev'}. '
                '${gap < 0.5 ? 'Only ${gap.toStringAsFixed(2)} m to danger!' : 'Gap: ${gap.toStringAsFixed(2)} m'}',
            highPriority: newSev == 'CRITICAL' || newSev == 'SEVERE',
          );
          alertsFired++;
        }
      }

      lastSeverity[site] = newSev;
    } catch (e) {
      debugPrint('[AiBg] error for $site: $e');
    }

    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  await prefs.setString(_kPrefKey, jsonEncode(lastSeverity));
  debugPrint(
      '[AiBg] done — $alertsFired alert(s) fired, ${stations.length} stations polled');
}

Future<List<dynamic>?> _cwcGet() async {
  try {
    final res = await http
        .get(Uri.parse('https://befiqr.in/cwc-ffs/bihar'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) return jsonDecode(res.body) as List;
  } catch (_) {}
  return null;
}

Future<List<String>> _fetchLiveStations() async {
  final list = await _cwcGet();
  if (list != null) {
    return list
        .map((e) => (e as Map<String, dynamic>)['site'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return [];
}

Future<Map<String, double>?> _fetchPrediction(String station) async {
  try {
    final j = await OpsClient.instance.get('/api/predict/$station');
    if (j != null) {
      return {
        'currentLevel': (j['current_level'] as num).toDouble(),
        'dangerLevel': (j['danger_level'] as num).toDouble(),
      };
    }
  } catch (_) {}

  try {
    final list = await _cwcGet();
    if (list != null) {
      final match = list.cast<Map<String, dynamic>?>().firstWhere(
            (e) => (e?['site'] as String? ?? '')
                .toLowerCase()
                .contains(station.toLowerCase()),
            orElse: () => null,
          );
      if (match != null) {
        return {
          'currentLevel': (match['current_level'] as num?)?.toDouble() ?? 0,
          'dangerLevel': (match['danger_level'] as num?)?.toDouble() ?? 1,
        };
      }
    }
  } catch (_) {}
  return null;
}

String _severity(double level, double danger) {
  if (danger <= 0) return 'LOW';
  final pct = level / danger;
  if (pct >= 1.00) return 'CRITICAL';
  if (pct >= 0.97) return 'SEVERE';
  if (pct >= 0.85) return 'MODERATE';
  return 'LOW';
}

int _sevRank(String s) => switch (s) {
      'CRITICAL' => 3,
      'SEVERE' => 2,
      'MODERATE' => 1,
      _ => 0,
    };

String _sevEmoji(String s) => switch (s) {
      'CRITICAL' => '\ud83d\udd34',
      'SEVERE' => '\ud83d\udfe0',
      'MODERATE' => '\ud83d\udfe1',
      _ => '\ud83d\udfe2',
    };
