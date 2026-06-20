// lib/pipeline/m1_source_registry.dart
//
// MODULE 1 — Source Registry
// All HTTP/scrape calls in one place. Returns List<FloodRecord> per source.
// Failures are isolated — one broken source never kills the cycle.

library pipeline.source_registry;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'm0_canonical_model.dart';

String _normaliseKey(String state, String station) =>
    '${state.toLowerCase().replaceAll(' ', '_')}:'
    '${station.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

double? _d(dynamic v) => v == null ? null : double.tryParse('$v');

GaugeThresholds _thresh(dynamic wl, dynamic dl, dynamic hfl) =>
    GaugeThresholds(
      warningLevel: _d(wl),
      dangerLevel:  _d(dl),
      hfl:          _d(hfl),
    );

class SourceResult {
  final String            sourceName;
  final List<FloodRecord> records;
  final bool              healthy;
  final String?           error;
  final Duration          latency;

  const SourceResult({
    required this.sourceName,
    required this.records,
    required this.healthy,
    this.error,
    required this.latency,
  });
}

class SourceRegistry {
  SourceRegistry._();
  static final SourceRegistry instance = SourceRegistry._();

  static const _kHttp = Duration(seconds: 20);

  Future<List<SourceResult>> fetchAll() async {
    return Future.wait([
      _guard('WRD_BIHAR',  _fetchWrdBihar),
      _guard('KOSI',       _fetchKosi),
      _guard('CWC_DIRECT', _fetchCwcDirect),
      _guard('BEFIQR',     _fetchBefiqr),
      _guard('GLOFAS',     _fetchGlofas),
    ], eagerError: false);
  }

  Future<SourceResult> _guard(
    String name,
    Future<List<FloodRecord>> Function() fn,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final records = await fn().timeout(_kHttp);
      sw.stop();
      return SourceResult(sourceName: name, records: records, healthy: true, latency: sw.elapsed);
    } catch (e, st) {
      sw.stop();
      debugPrint('[M1:$name] ERROR: $e\n$st');
      return SourceResult(sourceName: name, records: [], healthy: false, error: e.toString(), latency: sw.elapsed);
    }
  }

  Future<List<FloodRecord>> _fetchWrdBihar() async {
    const url = 'https://beams.fmiscwrdbihar.gov.in/api/v1/stations/live';
    final res  = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('WRD HTTP \${res.statusCode}');
    final body = json.decode(res.body);
    final list = (body['data'] ?? body) as List<dynamic>;
    return list.map<FloodRecord>((raw) {
      final name  = (raw['station_name'] ?? raw['name'] ?? '').toString();
      final river = (raw['river_name']   ?? raw['river'] ?? '').toString();
      return FloodRecord(
        stationKey:   _normaliseKey('bihar', name),
        stationName:  name,
        river:        river,
        state:        'Bihar',
        lat:          _d(raw['lat'] ?? raw['latitude']),
        lon:          _d(raw['lon'] ?? raw['longitude']),
        currentLevel: _d(raw['current_level'] ?? raw['water_level']),
        thresholds:   _thresh(raw['warning_level'] ?? raw['wl'], raw['danger_level'] ?? raw['dl'], raw['hfl']),
        riskLevel:    RiskLevel.fromString(raw['risk_level']?.toString()),
        source:       DataSource.wrdBihar,
        fetchedAt:    DateTime.now(),
      );
    }).toList();
  }

  Future<List<FloodRecord>> _fetchKosi() async {
    const url = 'https://irrigation.befiqr.in/flood/kosi-live';
    final res  = await http.get(Uri.parse(url), headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) throw Exception('Kosi HTTP \${res.statusCode}');
    final body = json.decode(res.body);
    final list = (body['stations'] ?? body['data'] ?? []) as List<dynamic>;
    return list.map<FloodRecord>((raw) {
      final name = (raw['station'] ?? raw['name'] ?? 'Birpur').toString();
      return FloodRecord(
        stationKey:   _normaliseKey('bihar', name),
        stationName:  name,
        river:        'Kosi',
        state:        'Bihar',
        lat:          _d(raw['lat']),
        lon:          _d(raw['lon']),
        currentLevel: _d(raw['level'] ?? raw['water_level']),
        thresholds:   _thresh(raw['wl'], raw['dl'], raw['hfl']),
        riskLevel:    RiskLevel.fromString(raw['status']?.toString()),
        source:       DataSource.kosi,
        fetchedAt:    DateTime.now(),
      );
    }).toList();
  }

  Future<List<FloodRecord>> _fetchCwcDirect() async {
    const url = 'https://cwc.gov.in/flood-forecast-api';
    final res  = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('CWC HTTP \${res.statusCode}');
    final body = json.decode(res.body);
    final list = (body['forecasts'] ?? body['stations'] ?? []) as List<dynamic>;
    return list.map<FloodRecord>((raw) {
      final name  = (raw['station_name'] ?? raw['station'] ?? '').toString();
      final state = (raw['state'] ?? 'India').toString();
      return FloodRecord(
        stationKey:   _normaliseKey(state, name),
        stationName:  name,
        river:        (raw['river'] ?? '').toString(),
        state:        state,
        lat:          _d(raw['lat']),
        lon:          _d(raw['lon']),
        currentLevel: _d(raw['obs_level'] ?? raw['current_level']),
        thresholds:   _thresh(raw['warning'], raw['danger'], raw['hfl']),
        riskLevel:    RiskLevel.fromString(raw['flood_status']?.toString()),
        source:       DataSource.cwcDirect,
        fetchedAt:    DateTime.now(),
      );
    }).toList();
  }

  Future<List<FloodRecord>> _fetchBefiqr() async {
    const url = 'https://irrigation.befiqr.in/api/cwc-stations';
    final res  = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('BeFIQR HTTP \${res.statusCode}');
    final body = json.decode(res.body);
    final list = (body['data'] ?? body) as List<dynamic>;
    return list.map<FloodRecord>((raw) {
      final name  = (raw['name']  ?? raw['station'] ?? '').toString();
      final state = (raw['state'] ?? 'Bihar').toString();
      return FloodRecord(
        stationKey:   _normaliseKey(state, name),
        stationName:  name,
        river:        (raw['river'] ?? '').toString(),
        state:        state,
        lat:          _d(raw['lat']),
        lon:          _d(raw['lon']),
        currentLevel: _d(raw['level']),
        thresholds:   _thresh(raw['wl'], raw['dl'], raw['hfl']),
        riskLevel:    RiskLevel.fromString(raw['risk']?.toString()),
        source:       DataSource.befiqr,
        fetchedAt:    DateTime.now(),
      );
    }).toList();
  }

  static const _kBiharPoints = <(String, String, double, double)>[
    ('gandak_trivenighat',    'Gandak',      27.0, 84.5),
    ('burhi_gandak_muktapur', 'Burhi Gandak',26.4, 85.2),
    ('bagmati_dheng',         'Bagmati',     26.6, 85.7),
    ('kamla_jhanjharpur',     'Kamla',       26.4, 86.0),
    ('kosi_birpur',           'Kosi',        26.2, 86.9),
    ('mahananda_dhantola',    'Mahananda',   25.9, 87.8),
    ('sone_koilwar',          'Sone',        25.5, 84.8),
    ('ganga_patna',           'Ganga',       25.6, 85.1),
  ];

  Future<List<FloodRecord>> _fetchGlofas() async {
    const baseUrl = 'https://flood-api.open-meteo.com/v1/flood';
    final latStr  = _kBiharPoints.map((p) => p.$3).join(',');
    final lonStr  = _kBiharPoints.map((p) => p.$4).join(',');
    final uri = Uri.parse('$baseUrl?latitude=$latStr&longitude=$lonStr&daily=river_discharge&forecast_days=7');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('GloFAS HTTP \${res.statusCode}');
    final json0    = json.decode(res.body);
    final responses = json0 is List ? json0 : [json0];
    final records   = <FloodRecord>[];
    for (var i = 0; i < responses.length && i < _kBiharPoints.length; i++) {
      final point  = _kBiharPoints[i];
      final daily  = responses[i]['daily'] as Map<String, dynamic>?;
      final vals   = (daily?['river_discharge'] as List?)?.cast<num?>();
      final latest = vals?.firstWhere((v) => v != null, orElse: () => null);
      records.add(FloodRecord(
        stationKey:   _normaliseKey('bihar', point.$1),
        stationName:  point.$1.replaceAll('_', ' '),
        river:        point.$2,
        state:        'Bihar',
        lat:          point.$3,
        lon:          point.$4,
        dischargeCms: latest?.toDouble(),
        source:       DataSource.glofas,
        fetchedAt:    DateTime.now(),
      ));
    }
    return records;
  }
}
