// lib/services/fcm_topic_manager.dart
// OpsFlood — Module 7: Push Notifications & FCM Topics
//
// FcmTopicManager
// ─────────────────────────────────────────────────────────────────────────
// Manages FCM topic subscriptions for OpsFlood.
//
// Topic taxonomy:
//   Severity tiers (global):
//     flood_emergency   — HFL breach, embankment collapse
//     flood_critical    — above danger level
//     flood_warning     — above warning level / rapid rise
//     flood_info        — heavy rainfall, advisory
//
//   District-level (Bihar, opt-in):
//     district_<slug>   e.g. district_supaul, district_muzaffarpur
//
//   River-level (Bihar, opt-in):
//     river_kosi, river_gandak, river_bagmati, river_burhi_gandak
//     river_mahananda, river_kamla, river_adhwara
//
// All subscriptions are persisted to SharedPreferences so the
// app can restore them after reinstall / data clear.

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Topic constants ───────────────────────────────────────────────────────

class FcmTopics {
  static const String emergency = 'flood_emergency';
  static const String critical = 'flood_critical';
  static const String warning = 'flood_warning';
  static const String info = 'flood_info';

  static const List<String> severityTopics = [
    emergency,
    critical,
    warning,
    info,
  ];

  /// All 38 Bihar district slugs.
  static const List<String> biharDistricts = [
    'araria',
    'arwal',
    'aurangabad',
    'banka',
    'begusarai',
    'bhagalpur',
    'bhojpur',
    'buxar',
    'darbhanga',
    'gaya',
    'gopalganj',
    'jamui',
    'jehanabad',
    'kaimur',
    'katihar',
    'khagaria',
    'kishanganj',
    'lakhisarai',
    'madhepura',
    'madhubani',
    'munger',
    'muzaffarpur',
    'nalanda',
    'nawada',
    'patna',
    'purnia',
    'rohtas',
    'saharsa',
    'samastipur',
    'saran',
    'sheikhpura',
    'sheohar',
    'sitamarhi',
    'siwan',
    'supaul',
    'vaishali',
    'west_champaran',
    'east_champaran',
  ];

  /// All Bihar river slugs.
  static const List<String> biharRivers = [
    'kosi',
    'gandak',
    'bagmati',
    'burhi_gandak',
    'mahananda',
    'kamla',
    'adhwara',
  ];

  static String districtTopic(String slug) => 'district_$slug';
  static String riverTopic(String slug) => 'river_$slug';
}

// ── FcmTopicManager ──────────────────────────────────────────────────────────

class FcmTopicManager {
  FcmTopicManager._();
  static final FcmTopicManager instance = FcmTopicManager._();

  static const _prefsKey = 'fcm_subscribed_topics';

  final _fcm = FirebaseMessaging.instance;
  final _subscribedTopics = <String>{};
  final _controller = StreamController<Set<String>>.broadcast();

  /// Stream of currently subscribed topics (emits on every change).
  Stream<Set<String>> get topicsStream => _controller.stream;

  /// Current snapshot (unmodifiable).
  Set<String> get currentTopics => Set.unmodifiable(_subscribedTopics);

  // ── Init ────────────────────────────────────────────────────────────

  /// Call once from main() after Firebase.initializeApp().
  /// Restores persisted subscriptions and re-subscribes to FCM.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? [];

    if (stored.isEmpty) {
      // First run: subscribe to all severity topics by default.
      await subscribeToAll(FcmTopics.severityTopics);
    } else {
      // Restore saved subscriptions.
      for (final topic in stored) {
        await _fcmSubscribe(topic);
        _subscribedTopics.add(topic);
      }
      _emit();
    }
    debugPrint('[FCM] Restored ${_subscribedTopics.length} topics');
  }

  // ── Public subscribe / unsubscribe ──────────────────────────────────

  Future<void> subscribeTo(String topic) async {
    if (_subscribedTopics.contains(topic)) return;
    await _fcmSubscribe(topic);
    _subscribedTopics.add(topic);
    await _persist();
    _emit();
  }

  Future<void> unsubscribeFrom(String topic) async {
    if (!_subscribedTopics.contains(topic)) return;
    await _fcm.unsubscribeFromTopic(topic);
    _subscribedTopics.remove(topic);
    await _persist();
    _emit();
  }

  Future<void> subscribeToAll(List<String> topics) async {
    for (final t in topics) {
      if (!_subscribedTopics.contains(t)) {
        await _fcmSubscribe(t);
        _subscribedTopics.add(t);
      }
    }
    await _persist();
    _emit();
  }

  Future<void> unsubscribeFromAll(List<String> topics) async {
    for (final t in topics) {
      if (_subscribedTopics.contains(t)) {
        await _fcm.unsubscribeFromTopic(t);
        _subscribedTopics.remove(t);
      }
    }
    await _persist();
    _emit();
  }

  /// Toggle a topic and return the new state.
  Future<bool> toggle(String topic) async {
    if (_subscribedTopics.contains(topic)) {
      await unsubscribeFrom(topic);
      return false;
    } else {
      await subscribeTo(topic);
      return true;
    }
  }

  bool isSubscribed(String topic) => _subscribedTopics.contains(topic);

  // ── District / river helpers ─────────────────────────────────────────

  Future<void> setDistrictSubscriptions(List<String> districtSlugs) async {
    // Unsubscribe from all current district topics.
    final currentDistricts =
        _subscribedTopics.where((t) => t.startsWith('district_')).toList();
    await unsubscribeFromAll(currentDistricts);
    // Subscribe to new selection.
    await subscribeToAll(districtSlugs.map(FcmTopics.districtTopic).toList());
  }

  Future<void> setRiverSubscriptions(List<String> riverSlugs) async {
    final current =
        _subscribedTopics.where((t) => t.startsWith('river_')).toList();
    await unsubscribeFromAll(current);
    await subscribeToAll(riverSlugs.map(FcmTopics.riverTopic).toList());
  }

  List<String> get subscribedDistricts => _subscribedTopics
      .where((t) => t.startsWith('district_'))
      .map((t) => t.replaceFirst('district_', ''))
      .toList();

  List<String> get subscribedRivers => _subscribedTopics
      .where((t) => t.startsWith('river_'))
      .map((t) => t.replaceFirst('river_', ''))
      .toList();

  // ── Internal ───────────────────────────────────────────────────────────

  Future<void> _fcmSubscribe(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('[FCM] subscribe error for $topic: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _subscribedTopics.toList());
  }

  void _emit() => _controller.add(Set.unmodifiable(_subscribedTopics));
}
