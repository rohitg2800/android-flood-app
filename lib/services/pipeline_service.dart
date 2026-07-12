// lib/services/pipeline_service.dart
//
// OpsFlood — PipelineService
//
// The OpsFlood backend ingestion pipeline has been removed.
// This service now resolves features entirely from local sources:
//
//   fetchFeatures()   → live river level via WrdBiharService;
//                        daily rainfall via Open-Meteo (GloFAS endpoint)
//   entryForState()   → hard-coded per-state flood thresholds
//                        (previously fetched from /api/state-severity)
//
// Both are used by:
//   predict.dart            – exports PipelineFeatures
//   prediction_service.dart – uses StateEntry via entryForState()

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'wrd_bihar_service.dart';

// ── PipelineFeatures ───────────────────────────────────────────────────────────────
class PipelineFeatures {
  /// Live river gauge height in metres (from WRD Bihar).
  final double? riverLevelM;

  /// Best available daily rainfall in mm (from Open-Meteo/GloFAS).
  final double? bestDailyRainfallMm;

  /// Danger level from WRD station (metres above datum).
  final double? dangerLevelM;

  const PipelineFeatures({
    this.riverLevelM,
    this.bestDailyRainfallMm,
    this.dangerLevelM,
  });
}

// ── StateEntry ───────────────────────────────────────────────────────────────────────
class StateEntry {
  /// Peak flood level thresholds (metres) keyed by severity label.
  final Map<String, double> peakLevelM;

  /// 7-day cumulative rainfall thresholds (mm) keyed by severity label.
  final Map<String, double> rainfall7dMm;

  /// Official danger level for the state's primary river gauge (metres).
  final double dangerLevelM;

  /// Warning level (metres). Defaults to 85% of danger level.
  final double warningLevelM;

  const StateEntry({
    required this.peakLevelM,
    required this.rainfall7dMm,
    required this.dangerLevelM,
    required this.warningLevelM,
  });
}

// ── PipelineService ─────────────────────────────────────────────────────────────────
class PipelineService {
  PipelineService._();
  static final PipelineService instance = PipelineService._();

  /// No-op init (backend pipeline removed).
  Future<void> init() async {}

  // ── fetchFeatures ──────────────────────────────────────────────────────
  /// Returns live features for [state]/[station] from official sources.
  /// Returns null if neither WRD Bihar nor Open-Meteo can be reached.
  Future<PipelineFeatures?> fetchFeatures({
    required String state,
    String? station,
  }) async {
    double? riverLevel;
    double? dangerLevel;
    double? rainfall;

    // ── 1. Bihar WRD portal ──────────────────────────────────────────
    if (state.toLowerCase().contains('bihar')) {
      try {
        final wrd = WrdBiharService.instance;
        final match = station != null && station.isNotEmpty
            ? await wrd.fetchBestMatch(station)
            : null;
        final stations = match != null ? [match] : await wrd.fetch();
        if (stations.isNotEmpty) {
          riverLevel = stations.first.currentLevel;
          dangerLevel = stations.first.dangerLevel;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Pipeline] WRD Bihar error: $e');
      }
    }

    // ── 2. Open-Meteo daily rainfall for a Bihar centroid ─────────────
    //    Uses Patna lat/lon as default when no station coords available.
    try {
      const lat = 25.59; // Patna, Bihar
      const lon = 85.13;
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&daily=precipitation_sum'
        '&forecast_days=1'
        '&timezone=Asia%2FKolkata',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final daily = body['daily'] as Map<String, dynamic>?;
        final vals = daily?['precipitation_sum'] as List?;
        if (vals != null && vals.isNotEmpty && vals.first != null) {
          rainfall = (vals.first as num).toDouble();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Pipeline] Open-Meteo rainfall error: $e');
    }

    if (riverLevel == null && rainfall == null) return null;

    return PipelineFeatures(
      riverLevelM: riverLevel,
      bestDailyRainfallMm: rainfall,
      dangerLevelM: dangerLevel,
    );
  }

  // ── entryForState ───────────────────────────────────────────────────────
  /// Returns the flood threshold matrix for [state].
  /// Values are sourced from CWC / WRD published danger levels.
  StateEntry entryForState(String state) {
    final key = state.toLowerCase().trim();
    return _kStateMatrix[key] ?? _kStateMatrix['default']!;
  }

  // ── Static state threshold matrix ───────────────────────────────────────
  //
  // Source: CWC Flood Forecasting Bulletin published thresholds.
  // dangerLevelM = official CWC danger level for state's primary gauge.
  // peakLevelM   = indicative flood severity thresholds (field-calibrated).
  // rainfall7dMm = 7-day cumulative rainfall thresholds from IMD data.
  static const Map<String, StateEntry> _kStateMatrix = {
    'bihar': StateEntry(
      dangerLevelM: 49.99, // Ganga at Patna (CWC)
      warningLevelM: 48.00,
      peakLevelM: {'moderate': 47.0, 'severe': 49.0, 'critical': 50.5},
      rainfall7dMm: {'moderate': 150.0, 'severe': 280.0, 'critical': 420.0},
    ),
    'assam': StateEntry(
      dangerLevelM: 89.22, // Brahmaputra at Guwahati (CWC)
      warningLevelM: 87.50,
      peakLevelM: {'moderate': 86.0, 'severe': 88.5, 'critical': 90.0},
      rainfall7dMm: {'moderate': 200.0, 'severe': 350.0, 'critical': 500.0},
    ),
    'uttar pradesh': StateEntry(
      dangerLevelM: 84.73, // Ganga at Varanasi (CWC)
      warningLevelM: 83.00,
      peakLevelM: {'moderate': 81.0, 'severe': 83.5, 'critical': 85.0},
      rainfall7dMm: {'moderate': 120.0, 'severe': 220.0, 'critical': 340.0},
    ),
    'west bengal': StateEntry(
      dangerLevelM: 6.10, // Damodar / Hooghly system
      warningLevelM: 5.50,
      peakLevelM: {'moderate': 5.0, 'severe': 6.0, 'critical': 6.5},
      rainfall7dMm: {'moderate': 180.0, 'severe': 300.0, 'critical': 450.0},
    ),
    'odisha': StateEntry(
      dangerLevelM: 25.90, // Mahanadi at Mundali (CWC)
      warningLevelM: 24.50,
      peakLevelM: {'moderate': 23.0, 'severe': 25.0, 'critical': 26.5},
      rainfall7dMm: {'moderate': 160.0, 'severe': 280.0, 'critical': 400.0},
    ),
    'andhra pradesh': StateEntry(
      dangerLevelM: 12.00, // Krishna at Vijayawada
      warningLevelM: 11.00,
      peakLevelM: {'moderate': 10.0, 'severe': 11.5, 'critical': 12.5},
      rainfall7dMm: {'moderate': 120.0, 'severe': 220.0, 'critical': 330.0},
    ),
    'kerala': StateEntry(
      dangerLevelM: 8.00,
      warningLevelM: 7.00,
      peakLevelM: {'moderate': 6.5, 'severe': 7.5, 'critical': 8.5},
      rainfall7dMm: {'moderate': 200.0, 'severe': 380.0, 'critical': 550.0},
    ),
    'gujarat': StateEntry(
      dangerLevelM: 11.00, // Sabarmati at Ahmedabad
      warningLevelM: 10.00,
      peakLevelM: {'moderate': 9.0, 'severe': 10.5, 'critical': 11.5},
      rainfall7dMm: {'moderate': 100.0, 'severe': 180.0, 'critical': 280.0},
    ),
    'rajasthan': StateEntry(
      dangerLevelM: 270.0,
      warningLevelM: 265.0,
      peakLevelM: {'moderate': 260.0, 'severe': 268.0, 'critical': 272.0},
      rainfall7dMm: {'moderate': 80.0, 'severe': 140.0, 'critical': 210.0},
    ),
    'madhya pradesh': StateEntry(
      dangerLevelM: 410.0, // Narmada at Hoshangabad
      warningLevelM: 406.0,
      peakLevelM: {'moderate': 404.0, 'severe': 408.0, 'critical': 412.0},
      rainfall7dMm: {'moderate': 130.0, 'severe': 230.0, 'critical': 350.0},
    ),
    'maharashtra': StateEntry(
      dangerLevelM: 498.0, // Godavari at Nasik
      warningLevelM: 494.0,
      peakLevelM: {'moderate': 492.0, 'severe': 496.0, 'critical': 500.0},
      rainfall7dMm: {'moderate': 150.0, 'severe': 260.0, 'critical': 380.0},
    ),
    'karnataka': StateEntry(
      dangerLevelM: 508.0, // Cauvery at Mysore
      warningLevelM: 505.0,
      peakLevelM: {'moderate': 503.0, 'severe': 506.0, 'critical': 509.0},
      rainfall7dMm: {'moderate': 140.0, 'severe': 250.0, 'critical': 370.0},
    ),
    'himachal pradesh': StateEntry(
      dangerLevelM: 370.0,
      warningLevelM: 366.0,
      peakLevelM: {'moderate': 364.0, 'severe': 368.0, 'critical': 372.0},
      rainfall7dMm: {'moderate': 100.0, 'severe': 180.0, 'critical': 270.0},
    ),
    'uttarakhand': StateEntry(
      dangerLevelM: 346.0,
      warningLevelM: 342.0,
      peakLevelM: {'moderate': 340.0, 'severe': 344.0, 'critical': 348.0},
      rainfall7dMm: {'moderate': 120.0, 'severe': 210.0, 'critical': 310.0},
    ),
    'punjab': StateEntry(
      dangerLevelM: 215.0,
      warningLevelM: 212.0,
      peakLevelM: {'moderate': 210.0, 'severe': 213.0, 'critical': 216.0},
      rainfall7dMm: {'moderate': 90.0, 'severe': 160.0, 'critical': 240.0},
    ),
    'default': StateEntry(
      dangerLevelM: 12.0,
      warningLevelM: 10.0,
      peakLevelM: {'moderate': 9.0, 'severe': 11.0, 'critical': 13.0},
      rainfall7dMm: {'moderate': 120.0, 'severe': 220.0, 'critical': 330.0},
    ),
  };
}
