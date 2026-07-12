// lib/services/real_time_service.dart  (v2.1 — emergency contacts wired)
//
// v2.0 — unchanged from v2.0 except:
// v2.1 — emergency contacts loaded from assets/data/emergency_contacts.json
//         on first startPolling() call.  emergencyContactsForState() filters
//         by state name (case-insensitive).  The List<EmergencyContact> type
//         from flood_data.dart is used so CollapsibleContacts renders correctly.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import 'live_fetch_engine.dart';

class RealTimeService extends ChangeNotifier {
  static final RealTimeService _instance = RealTimeService._internal();
  factory RealTimeService() => _instance;

  final LiveFetchEngine _fetchEngine = LiveFetchEngine();
  bool _disposed = false;

  // Emergency contacts loaded from asset
  final Map<String, List<EmergencyContact>> _contactsByState = {};
  bool _contactsLoaded = false;

  RealTimeService._internal() {
    _fetchEngine.onStateChanged = () {
      if (!_disposed) notifyListeners();
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _fetchEngine.stopPolling();
    _fetchEngine.onStateChanged = null;
    super.dispose();
  }

  // ── Status passthrough ────────────────────────────────────────────────
  bool get isLoading => _fetchEngine.isLoading;
  bool get isOnline => _fetchEngine.isOnline;
  bool get isUsingFallback =>
      !_fetchEngine.isOnline && _fetchEngine.liveFloodData.isNotEmpty;
  bool get isWakingUp => _fetchEngine.isWakingUp;
  bool get isUsingCache => _fetchEngine.isUsingCache;
  DateTime? get lastFetchTime => _fetchEngine.lastFetchTime;
  String? get error => _fetchEngine.error;
  int get queuedOfflineCycles => _fetchEngine.queuedOfflineCycles;

  // ── Per-source health passthrough ──────────────────────────────────────
  SourceHealth get glofasHealth => _fetchEngine.glofasHealth;
  SourceHealth get imdHealth => _fetchEngine.imdHealth;
  SourceHealth get wrdHealth => _fetchEngine.wrdHealth;
  SourceHealth get cwcHealth => _fetchEngine.cwcHealth;

  bool get glofasHealthy => _fetchEngine.glofasHealthy;
  bool get imdHealthy => _fetchEngine.imdHealthy;
  bool get wrdHealthy => _fetchEngine.wrdHealthy;
  bool get cwcHealthy => _fetchEngine.cwcHealthy;

  int? get glofasLatencyMs => _fetchEngine.glofasLatencyMs;
  int? get imdLatencyMs => _fetchEngine.imdLatencyMs;
  int? get wrdLatencyMs => _fetchEngine.wrdLatencyMs;
  int? get cwcLatencyMs => _fetchEngine.cwcLatencyMs;

  // ── Data passthrough ─────────────────────────────────────────────────
  List<FloodData> get liveLevels => _fetchEngine.liveFloodData;

  List<dynamic> get activeCriticalAlerts => _fetchEngine.activeCriticalAlerts;
  List<dynamic> get criticalAlerts => _fetchEngine.criticalAlerts;
  int get criticalCount => _fetchEngine.criticalCount;
  List<dynamic> get cwcStations => _fetchEngine.cwcStations;
  bool get hasCwcLiveData => _fetchEngine.hasCwcLiveData;
  MultiLocationMonitoring get monitoringData => _fetchEngine.monitoringData;

  List<dynamic> get imdAlerts => _fetchEngine.imdAlerts;
  List<dynamic> get ndmaAdvisories => _fetchEngine.ndmaAdvisories;
  List<dynamic> get emergencyContacts => _fetchEngine.emergencyContacts;

  Map<String, dynamic> get debugLevelsRaw => _fetchEngine.debugLevelsRaw;
  Map<String, dynamic> get debugCwcRaw => _fetchEngine.debugCwcRaw;
  int get debugRetryCount => _fetchEngine.debugRetryCount;
  int get debugWakeAttempts => _fetchEngine.debugWakeAttempts;

  // ── Per-city ─────────────────────────────────────────────────────────
  List<RiverLevelSnapshot> trendForCity(String city) =>
      _fetchEngine.trendForCity(city).cast<RiverLevelSnapshot>();

  FloodData? dataForCity(String city) => _fetchEngine.floodDataForCity(city);

  List<dynamic> imdAlertsForState(String state) =>
      _fetchEngine.imdAlertsForState(state);
  List<dynamic> ndmaAdvisoriesForState(String state) =>
      _fetchEngine.ndmaAdvisoriesForState(state);

  /// Returns emergency contacts for [state] from the bundled asset JSON.
  /// Falls back to empty list if asset not yet loaded or state not found.
  List<EmergencyContact> emergencyContactsForState(String state) {
    if (!_contactsLoaded) return const [];
    final key = state.trim().toLowerCase();
    return _contactsByState.entries
        .where((e) => e.key.toLowerCase() == key)
        .expand((e) => e.value)
        .toList();
  }

  // ── Actions ─────────────────────────────────────────────────────────
  Future<void> refreshData() async => _fetchEngine.refreshData();

  /// Start the polling engine and pre-load emergency contacts from asset.
  Future<void> startPolling() async {
    if (!_contactsLoaded) await _loadEmergencyContacts();
    return _fetchEngine.startPolling();
  }

  void stopPolling() => _fetchEngine.stopPolling();

  // ── Asset loader ─────────────────────────────────────────────────────
  Future<void> _loadEmergencyContacts() async {
    try {
      final raw =
          await rootBundle.loadString('assets/data/emergency_contacts.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list =
          (json['contacts'] as List<dynamic>).cast<Map<String, dynamic>>();
      for (final c in list) {
        final state = (c['state'] as String).trim();
        _contactsByState.putIfAbsent(state, () => []).add(
              EmergencyContact(
                name: (c['name'] as String? ?? '').trim(),
                phone: (c['phone'] as String? ?? '').trim(),
                role: (c['role'] as String? ?? '').trim(),
              ),
            );
      }
      _contactsLoaded = true;
      debugPrint('[RealTimeService] loaded ${list.length} emergency contacts '
          'across ${_contactsByState.length} states');
    } catch (e) {
      debugPrint(
          '[RealTimeService] emergency contacts load failed (non-fatal): $e');
      _contactsLoaded = true; // don't retry endlessly
    }
  }
}
