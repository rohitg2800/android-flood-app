import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Resolves issue #23: Custom Alert Configuration
/// Stores per-user alert configs in Firestore
/// Note: FirebaseAuth removed — userId must be passed in by the caller.
class AlertConfig {
  final String id;
  final String userId;
  final String stationId;
  final String stationName;
  final double thresholdMeters;
  final AlertType alertType;
  final bool enabled;
  final QuietHours? quietHours;
  final DateTime? lastTriggered;

  const AlertConfig({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.stationName,
    required this.thresholdMeters,
    required this.alertType,
    this.enabled = true,
    this.quietHours,
    this.lastTriggered,
  });

  factory AlertConfig.fromMap(String id, Map<String, dynamic> map) {
    return AlertConfig(
      id: id,
      userId: map['user_id'] ?? '',
      stationId: map['station_id'] ?? '',
      stationName: map['station_name'] ?? '',
      thresholdMeters: (map['threshold_meters'] ?? 0.0).toDouble(),
      alertType: AlertType.values.firstWhere(
        (e) => e.name == map['alert_type'],
        orElse: () => AlertType.above,
      ),
      enabled: map['enabled'] ?? true,
      quietHours: map['quiet_hours'] != null
          ? QuietHours.fromMap(map['quiet_hours'])
          : null,
      lastTriggered: map['last_triggered'] != null
          ? DateTime.parse(map['last_triggered'])
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'station_id': stationId,
        'station_name': stationName,
        'threshold_meters': thresholdMeters,
        'alert_type': alertType.name,
        'enabled': enabled,
        'quiet_hours': quietHours?.toMap(),
        'last_triggered': lastTriggered?.toIso8601String(),
        'updated_at': FieldValue.serverTimestamp(),
      };

  AlertConfig copyWith({
    bool? enabled,
    double? thresholdMeters,
    QuietHours? quietHours,
  }) =>
      AlertConfig(
        id: id,
        userId: userId,
        stationId: stationId,
        stationName: stationName,
        thresholdMeters: thresholdMeters ?? this.thresholdMeters,
        alertType: alertType,
        enabled: enabled ?? this.enabled,
        quietHours: quietHours ?? this.quietHours,
        lastTriggered: lastTriggered,
      );
}

enum AlertType { above, below }

class QuietHours {
  final String start;
  final String end;

  const QuietHours({required this.start, required this.end});

  factory QuietHours.fromMap(Map<String, dynamic> map) =>
      QuietHours(start: map['start'] ?? '22:00', end: map['end'] ?? '06:00');

  Map<String, dynamic> toMap() => {'start': start, 'end': end};

  bool get isActiveNow {
    final now = DateTime.now();
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startMins = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMins = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    final currentMins = now.hour * 60 + now.minute;
    if (startMins > endMins) {
      return currentMins >= startMins || currentMins < endMins;
    }
    return currentMins >= startMins && currentMins < endMins;
  }
}

class AlertConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // userId must be injected — call setUserId() after auth resolves
  String? _userId;
  void setUserId(String? uid) => _userId = uid;
  String? get currentUserId => _userId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('alert_configs');

  Stream<List<AlertConfig>> watchAlertConfigs() {
    if (_userId == null) return const Stream.empty();
    return _collection.where('user_id', isEqualTo: _userId).snapshots().map(
        (snap) =>
            snap.docs.map((d) => AlertConfig.fromMap(d.id, d.data())).toList());
  }

  Future<List<AlertConfig>> getAlertConfigs() async {
    if (_userId == null) return [];
    try {
      final snap = await _collection.where('user_id', isEqualTo: _userId).get();
      return snap.docs.map((d) => AlertConfig.fromMap(d.id, d.data())).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AlertConfigService] getAlertConfigs: $e');
      return [];
    }
  }

  Future<String?> createAlertConfig(AlertConfig config) async {
    if (_userId == null) return null;
    try {
      final doc = await _collection.add(config.toMap());
      return doc.id;
    } catch (e) {
      if (kDebugMode) debugPrint('[AlertConfigService] create: $e');
      return null;
    }
  }

  Future<bool> updateAlertConfig(AlertConfig config) async {
    try {
      await _collection.doc(config.id).update(config.toMap());
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AlertConfigService] update: $e');
      return false;
    }
  }

  Future<bool> deleteAlertConfig(String configId) async {
    try {
      await _collection.doc(configId).delete();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AlertConfigService] delete: $e');
      return false;
    }
  }

  Future<bool> toggleAlertConfig(String configId, bool enabled) async {
    try {
      await _collection.doc(configId).update({
        'enabled': enabled,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AlertConfigService] toggle: $e');
      return false;
    }
  }
}
