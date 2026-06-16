// lib/services/fcm_broadcast_service.dart  v2
// Fixed:
//   • DataFetchSnapshot — now defined in data_fetch_engine.dart
//   • StreamBuilder typed correctly
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'alert_engine.dart';
import 'data_fetch_engine.dart';
import 'fcm_templates.dart';

class FcmBroadcastService {
  FcmBroadcastService._();
  static final FcmBroadcastService instance = FcmBroadcastService._();

  StreamSubscription<DataFetchSnapshot>? _sub;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _sub = DataFetchEngine.instance.stream.listen(_onSnapshot);
  }

  void stop() {
    _sub?.cancel();
    _sub     = null;
    _started = false;
  }

  void _onSnapshot(DataFetchSnapshot snap) {
    if (snap.isLoading || snap.stations.isEmpty) return;
    // Build lightweight FloodAlerts for any station above warning level
    final now = DateTime.now();
    for (final d in snap.stations) {
      if (d.currentLevel < d.warningLevel) continue;
      final alert = FloodAlert(
        id:             '${d.stationId}_fcm_${now.day}',
        stationName:    d.stationName,
        title:          '${d.city} — ${d.riskLevel.toUpperCase()}',
        river:          d.river,
        district:       d.district,
        currentLevel:   d.currentLevel,
        dangerLevel:    d.dangerLevel,
        warningLevel:   d.warningLevel,
        hfl:            d.hfl,
        thresholdLevel: d.warningLevel,
        severity:       d.currentLevel >= d.dangerLevel
            ? AlertSeverity.critical : AlertSeverity.warning,
        type:           d.currentLevel >= d.dangerLevel
            ? AlertType.levelAboveDanger : AlertType.levelAboveWarning,
        issuedAt:       now,
        message:        d.riskLevel,
        state:          d.state,
      );
      final payload = FcmTemplates.instance.buildPayload(alert);
      _broadcastToTopic(payload, alert);
    }
  }

  void _broadcastToTopic(dynamic payload, FloodAlert alert) {
    // Topic subscription is done client-side; server push is handled by backend.
    // This method exists as a hook for future server-side FCM admin SDK calls.
    final topic = FcmTemplates.topicFor(alert);
    // ignore: avoid_print
    assert(() {
      debugPrint('[FcmBroadcast] would broadcast to $topic: ${payload.title}');
      return true;
    }());
  }
}
