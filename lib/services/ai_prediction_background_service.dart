// lib/services/ai_prediction_background_service.dart
//
// Background AI-prediction polling, rewritten to use WorkManager.
// Drops flutter_background_service (was never in pubspec).
//
// Architecture
// ────────────
//  • WorkManager periodic task fires every 30 minutes.
//  • Each run fetches AI severity for every live CWC Bihar station.
//  • If severity worsens vs the last run (stored in SharedPreferences)
//    a local notification is fired.
//  • Public API is identical to the previous flutter_background_service
//    version so call-sites need no changes.
//
// Setup (call once from main.dart before runApp)
// ─────
//   await AiPredictionBgService.initialise();
//   await AiPredictionBgService.start();
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kTaskName       = 'aiPredictionPoll';
const _kTaskUniqueName = 'ai_prediction_periodic';
const _kChannelId      = 'ai_flood_bg';
const _kChannelName    = 'AI Flood Monitor';
const _kFgNotifId      = 9000;
const _kAlertBaseId    = 9100;
const _kPrefKey        = 'ai_bg_last_severity';

const String _backendBase = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://opsflood-api.onrender.com',
);

// ─────────────────────────────────────────────────────────────────────────────
// WorkManager top-level callback
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void aiPredictionCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await _initNotifications();
      await _pollAll();
    } catch (e) {
      debugPrint('[AiBg] poll error: $e');
    }
    return true; // always succeed to avoid WM retry storms
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

class AiPredictionBgService {
  AiPredictionBgService._();

  static const int kPollIntervalMinutes = 30;

  /// Call once from main.dart — initialises WorkManager + notification channel.
  static Future<void> initialise() async {
    await _initNotifications();
    await Workmanager().initialize(
      aiPredictionCallbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  /// Enqueue the periodic poll task (idempotent — safe to call multiple times).
  static Future<void> start() async {
    await Workmanager().registerPeriodicTask(
      _kTaskUniqueName,
      _kTaskName,
      frequency:          Duration(minutes: kPollIntervalMinutes),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(
        networkType:           NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      backoffPolicy:      BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
    debugPrint('[AiBg] periodic poll registered (${kPollIntervalMinutes} min)');
  }

  /// Cancel the periodic task.
  static Future<void> stop() async {
    await Workmanager().cancelByUniqueName(_kTaskUniqueName);
    debugPrint('[AiBg] periodic poll cancelled');
  }

  /// WorkManager tasks are fire-and-forget; always returns false.
  static Future<bool> get isRunning async => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifications
// ─────────────────────────────────────────────────────────────────────────────

final _notif = FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios     = DarwinInitializationSettings();
  await _notif.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );
  const channel = AndroidNotificationChannel(
    _kChannelId,
    _kChannelName,
    description:      'Live AI flood severity alerts',
    importance:       Importance.high,
    playSound:        true,
    enableVibration:  true,
  );
  await _notif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> _showAlert({
  required int    id,
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
        importance:       highPriority ? Importance.high : Importance.defaultImportance,
        priority:         highPriority ? Priority.high   : Priority.defaultPriority,
        icon:             '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Poll logic
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _kSeedStations = [
  'Gandhighat', 'Hathidah', 'Digha Ghat', 'Gandhi Setu',
  'Munger', 'Bhagalpur', 'Sultanganj', 'Kahalgaon', 'Farakka',
  'Birpur', 'Baltara', 'Rosera', 'Benibad', 'Hayaghat',
  'Khagaria', 'Minapur', 'Lalganj', 'Bettiah', 'Bagaha',
  'Valmikinagar', 'Triveni', 'Banmankhi', 'Purnea', 'Forbesganj',
  'Araria', 'Sitamarhi', 'Muzaffarpur', 'Motihari',
  'Darbhanga', 'Samastipur', 'Patna',
];

Future<void> _pollAll() async {
  final prefs = await SharedPreferences.getInstance();
  final Map<String, String> lastSeverity = Map<String, String>.from(
    jsonDecode(prefs.getString(_kPrefKey) ?? '{}') as Map,
  );

  List<String> stations = await _fetchLiveStations();
  if (stations.isEmpty) stations = _kSeedStations;

  debugPrint('[AiBg] polling ${stations.length} stations');

  int alertsFired = 0;
  for (int i = 0; i < stations.length; i++) {
    final site = stations[i];
    try {
      final pred = await _fetchPrediction(site);
      if (pred == null) continue;

      final newSev = _severity(
        pred['currentLevel']!,
        pred['dangerLevel']!,
      );
      final oldSev = lastSeverity[site];

      if (oldSev != null && _sevRank(newSev) > _sevRank(oldSev)) {
        final gap = (pred['dangerLevel']! - pred['currentLevel']!).abs();
        await _showAlert(
          id:           _kAlertBaseId + i,
          title:        '⚠ $site — $newSev',
          body:         '${_sevEmoji(newSev)} Risk escalated '
                        '$oldSev → $newSev.  '
                        '${gap < 0.5
                            ? 'Only ${gap.toStringAsFixed(2)} m to danger!'
                            : 'Gap: ${gap.toStringAsFixed(2)} m'}',
          highPriority: newSev == 'CRITICAL' || newSev == 'SEVERE',
        );
        alertsFired++;
      }

      lastSeverity[site] = newSev;
    } catch (_) {}

    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  await prefs.setString(_kPrefKey, jsonEncode(lastSeverity));

  final now = DateTime.now();
  final ts  = '${now.hour.toString().padLeft(2, '0')}:'
              '${now.minute.toString().padLeft(2, '0')}';
  debugPrint('[AiBg] done — $alertsFired alert(s) · Last sync $ts');
}

// ─────────────────────────────────────────────────────────────────────────────
// HTTP helpers
// ─────────────────────────────────────────────────────────────────────────────

Future<List<String>> _fetchLiveStations() async {
  try {
    final res = await http
        .get(Uri.parse('https://befiqr.in/cwc-ffs/bihar'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list
          .map((e) => (e as Map<String, dynamic>)['site'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
  } catch (_) {}
  return [];
}

Future<Map<String, double>?> _fetchPrediction(String station) async {
  // 1. Backend LSTM
  try {
    final res = await http
        .get(Uri.parse('$_backendBase/api/predict/$station'))
        .timeout(const Duration(seconds: 18));
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return {
        'currentLevel': (j['current_level'] as num).toDouble(),
        'dangerLevel':  (j['danger_level']  as num).toDouble(),
      };
    }
  } catch (_) {}

  // 2. Befiqr CWC fallback
  try {
    final res = await http
        .get(Uri.parse('https://befiqr.in/cwc-ffs/bihar'))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      final match = list
          .cast<Map<String, dynamic>?>()
          .firstWhere(
            (e) => (e?['site'] as String? ?? '')
                .toLowerCase()
                .contains(station.toLowerCase()),
            orElse: () => null,
          );
      if (match != null) {
        return {
          'currentLevel': (match['current_level'] as num?)?.toDouble() ?? 0,
          'dangerLevel':  (match['danger_level']  as num?)?.toDouble() ?? 1,
        };
      }
    }
  } catch (_) {}

  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Severity helpers
// ─────────────────────────────────────────────────────────────────────────────

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
  'SEVERE'   => 2,
  'MODERATE' => 1,
  _          => 0,
};

String _sevEmoji(String s) => switch (s) {
  'CRITICAL' => '🔴',
  'SEVERE'   => '🟠',
  'MODERATE' => '🟡',
  _          => '🟢',
};
