// lib/pipeline/m4_enricher.dart
//
// MODULE 4 — Enricher
// A. Applies RTDAS thresholds from SharedPrefs
// B. Recomputes RiskLevel with single canonical algorithm
// C. Calls /predict/v2 ML enrichment for at-risk stations

library pipeline.enricher;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'm0_canonical_model.dart';

class _RtdasCache {
  static const _prefsKey   = 'rtdas_threshold_overrides_v1';
  static const _staleAfter = Duration(hours: 7);
  Map<String, GaugeThresholds> _data = {};
  DateTime? _loadedAt;
  bool get isStale =>
      _loadedAt == null || DateTime.now().difference(_loadedAt!) >= _staleAfter;
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_prefsKey);
      if (raw == null) return;
      final map   = json.decode(raw) as Map<String, dynamic>;
      _data = {};
      for (final kv in map.entries) {
        if (kv.key.startsWith('__')) continue;
        final v = kv.value as Map<String, dynamic>;
        _data[kv.key] = GaugeThresholds(
          warningLevel: (v['wl']  as num?)?.toDouble(),
          dangerLevel:  (v['dl']  as num?)?.toDouble(),
          hfl:          (v['hfl'] as num?)?.toDouble(),
        );
      }
      _loadedAt = DateTime.now();
      debugPrint('[M4:RtdasCache] loaded \${_data.length} entries');
    } catch (e) { debugPrint('[M4:RtdasCache] load error: $e'); }
  }
  GaugeThresholds? forStation(String k) => _data[k];
}

RiskLevel _computeRisk(double? level, GaugeThresholds t) {
  if (level == null) return RiskLevel.normal;
  if (t.hfl != null && level >= t.hfl!) return RiskLevel.critical;
  if (t.dangerLevel  != null && level >= t.dangerLevel!)  return RiskLevel.danger;
  if (t.warningLevel != null && level >= t.warningLevel!) return RiskLevel.warning;
  return RiskLevel.normal;
}

class _MlClient {
  static const _endpoint = 'https://opsflood-backend.up.railway.app/predict/v2';
  static const _timeout  = Duration(seconds: 15);
  Future<Map<String, dynamic>?> predict(Map<String, dynamic> payload) async {
    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body:    json.encode(payload),
      ).timeout(_timeout);
      if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
    } catch (e) { debugPrint('[M4:ML] predict error: $e'); }
    return null;
  }
}

class Enricher {
  Enricher._();
  static final Enricher instance = Enricher._();
  final _rtdas = _RtdasCache();
  final _ml    = _MlClient();

  Future<List<FloodRecord>> enrich(List<FloodRecord> records) async {
    if (_rtdas.isStale) await _rtdas.load();
    var enriched = records.map((r) {
      final rtdas  = _rtdas.forStation(r.stationKey);
      final merged = rtdas != null ? r.thresholds.merge(rtdas) : r.thresholds;
      final risk   = _computeRisk(r.currentLevel, merged);
      return r.copyWith(thresholds: merged, riskLevel: risk);
    }).toList();
    final candidates = enriched
        .where((r) => r.riskLevel != RiskLevel.normal && r.currentLevel != null)
        .toList();
    if (candidates.isNotEmpty) {
      final mlUpdates = await _mlEnrich(candidates);
      enriched = enriched.map((r) {
        final upd = mlUpdates[r.stationKey];
        return upd != null ? r.copyWith(
          predictedSeverity: upd['predicted_severity'] as double?,
          riskScore:         upd['risk_score']         as double?,
          confidencePercent: upd['confidence_percent'] as double?,
        ) : r;
      }).toList();
    }
    debugPrint('[M4:Enricher] enriched=\${enriched.length}  ml_updated=\${candidates.length}');
    return enriched;
  }

  Future<Map<String, Map<String, dynamic>>> _mlEnrich(List<FloodRecord> candidates) async {
    final payload = {
      'stations': candidates.map((r) => {
        'station_key':    r.stationKey,
        'river_level_m':  r.currentLevel,
        'rainfall_mm':    r.rainfallMm,
        'danger_level_m': r.thresholds.dangerLevel,
        'state':          r.state,
      }).toList(),
    };
    final resp = await _ml.predict(payload);
    if (resp == null) return {};
    final out  = <String, Map<String, dynamic>>{};
    final list = (resp['predictions'] ?? resp['results'] ?? []) as List<dynamic>;
    for (final p in list) {
      final key = p['station_key'] as String?;
      if (key != null) out[key] = p as Map<String, dynamic>;
    }
    return out;
  }
}
