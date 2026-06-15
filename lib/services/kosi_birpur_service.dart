// lib/services/kosi_birpur_service.dart  v3.3
//
// v3.3 (15 Jun 2026) — DATUM FIX:
//   All 5 live sources were emitting Kosi Birpur levels in AMSL (metres above
//   mean sea level), e.g. 212.05 m with a DL of 214.00 m AMSL.  Every other
//   Bihar station in the pipeline uses LOCAL GAUGE DATUM heights (70-77 m
//   range for Birpur), matching the kBiharGauges registry entry:
//     Birpur (CWC): WL 73.70 m, DL 74.70 m, HFL 76.02 m
//
//   Fix: subtract kBirpurDatumOffset (139.32 m, the AMSL elevation of local
//   gauge zero on the Kosi barrage CWC bench-mark) from every AMSL reading
//   before constructing KosiBirpurReading.  The threshold constants are also
//   expressed in local datum now so KosiBirpurReading.statusLabel is correct.
//
//   Conversion examples:
//     AMSL 212.05 → local  72.73 m  (ELEVATED, below WL 73.70)
//     AMSL 213.00 → local  73.68 m  (≈ WARNING)
//     AMSL 214.00 DL → local 74.68 m  (≈ DL 74.70, registry-consistent)
//     seed 210.80 AMSL → local 71.48 m
//
// v3.2: bumped _tryFromCwcService timeout 6s→12s.
// v3.1: Registry-locked DL/WL/HFL for all Bihar gauge items.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'befiqr_cwc_service.dart';

// ── Official CWC thresholds for Kosi @ Birpur — LOCAL GAUGE DATUM (m) ──────
// Datum offset: kBirpurDatumOffset = 139.32 m (AMSL of local gauge zero)
// Source: CWC bench-mark, Birpur Barrage, Supaul.
const double kBirpurDatumOffset      = 139.32;  // subtract from AMSL to get local gauge
const double kBirpurDangerLevel      =  74.70;  // local gauge (was 214.00 AMSL)
const double kBirpurWarningLevel     =  73.70;  // local gauge (was 213.00 AMSL)
const double kBirpurNormalLevel      =  71.48;  // local gauge (was 210.80 AMSL)
const double kBirpurHFL              =  76.02;  // local gauge (was 215.32 AMSL)
const double kBirpurWarningDischarge = 22000.0;
const double kBirpurDangerDischarge  = 27014.0;

// ─────────────────────────────────────────────────────────────────────────────
class KosiBirpurReading {
  final double  levelM;         // LOCAL GAUGE DATUM (m)
  final double  dangerLevel;    // LOCAL GAUGE DATUM (m)
  final double  warningLevel;   // LOCAL GAUGE DATUM (m)
  final double? dischargeCumecs;
  final double? levelWrd;
  final String? trend;
  final DateTime observedAt;
  final String   source;

  const KosiBirpurReading({
    required this.levelM,
    required this.dangerLevel,
    required this.warningLevel,
    this.dischargeCumecs,
    this.levelWrd,
    this.trend,
    required this.observedAt,
    required this.source,
  });

  double get gap        => dangerLevel - levelM;
  bool   get isDanger   => levelM >= dangerLevel;
  bool   get isWarning  => levelM >= warningLevel && levelM < dangerLevel;
  bool   get isElevated => levelM >= kBirpurNormalLevel && levelM < warningLevel;
  bool   get isNormal   => levelM < kBirpurNormalLevel;

  String get statusLabel {
    if (isDanger)   return 'DANGER';
    if (isWarning)  return 'WARNING';
    if (isElevated) return 'ELEVATED';
    return 'NORMAL';
  }

  double get fillFraction => (levelM / dangerLevel).clamp(0.0, 1.1);

  CwcStation toCwcStation() => CwcStation(
    river:        'Kosi',
    site:         'Birpur',
    currentLevel: levelM,
    dangerLevel:  dangerLevel,
    warningLevel: warningLevel,
    trend:        trend,
    source:       source,
    isFromSeed:   source == 'SEED',
    fetchedAt:    observedAt,
  );
}

// ── Datum conversion helper ───────────────────────────────────────────────────
/// Convert an AMSL reading to local gauge datum.
/// Returns null if the result is outside a plausible Kosi gauge range (50–90 m).
double? _amslToLocal(double? amsl) {
  if (amsl == null) return null;
  final local = amsl - kBirpurDatumOffset;
  // Sanity: local gauge at Birpur should be in 50-90 m range during normal to
  // extreme flood conditions.  Reject implausible values.
  if (local < 50 || local > 90) return null;
  return local;
}

// ── HTTP client that does NOT follow redirects ─────────────────────────────
http.Client _noRedirectClient() {
  final inner = HttpClient()..maxConnectionsPerHost = 4;
  inner.findProxy = null;
  return IOClient(inner);
}

Future<http.Response> _getNoLoop(String url,
    {Map<String, String>? headers, Duration timeout = const Duration(seconds: 10)}) async {
  final client = _noRedirectClient();
  try {
    final req    = http.Request('GET', Uri.parse(url));
    if (headers != null) req.headers.addAll(headers);
    final stream = await client.send(req).timeout(timeout);
    var resp      = await http.Response.fromStream(stream);

    if (resp.statusCode >= 300 && resp.statusCode < 400) {
      final loc = resp.headers['location'];
      if (loc != null) {
        final origPath  = Uri.parse(url).path.toLowerCase();
        final redirPath = Uri.parse(loc).path.toLowerCase();
        final isLoop = redirPath.contains(origPath) && redirPath != origPath;
        if (!isLoop) {
          final req2   = http.Request('GET', Uri.parse(loc));
          if (headers != null) req2.headers.addAll(headers);
          final stream2 = await client.send(req2).timeout(timeout);
          resp = await http.Response.fromStream(stream2);
        } else {
          debugPrint('[WRIS] redirect loop detected, aborting: $loc');
        }
      }
    }
    return resp;
  } finally {
    client.close();
  }
}

// ── KosiBirpurService ──────────────────────────────────────────────────────

class KosiBirpurService {
  static const _raceTimeout = Duration(seconds: 13);
  final BefiqrCwcService _cwcSvc = BefiqrCwcService();

  Future<KosiBirpurReading> fetchLive() async {
    final futures = <Future<KosiBirpurReading?>>[
      _tryBeamsDirect(),
      _tryFromCwcService(),
      _tryWRIS(),
      _tryFFSEndpoint('https://ffs.india-water.gov.in/ffs/pages/getFloodData.php'),
      _tryFFSEndpoint('https://ffs.india-water.gov.in/ffs/api/station/KOSI-BIRPUR'),
    ];

    final completer = Completer<KosiBirpurReading?>();
    int pending = futures.length;

    for (final f in futures) {
      f.then((result) {
        if (result != null && !completer.isCompleted) {
          completer.complete(result);
        } else {
          pending--;
          if (pending == 0 && !completer.isCompleted) completer.complete(null);
        }
      }).catchError((_) {
        pending--;
        if (pending == 0 && !completer.isCompleted) completer.complete(null);
      });
    }

    final result = await completer.future.timeout(
      _raceTimeout, onTimeout: () => null);
    return result ?? _seed();
  }

  // ── Source A: BEAMS Bihar direct JSON ──────────────────────────────────────
  // BEAMS returns levels in AMSL.  Convert to local gauge datum.
  Future<KosiBirpurReading?> _tryBeamsDirect() async {
    final urls = [
      'https://api.beams.bihar.gov.in/api/stations/live?river=KOSI&site=BIRPUR',
      'https://api.beams.bihar.gov.in/public/flood/stations?river=kosi',
    ];
    for (final url in urls) {
      try {
        final resp = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json', 'User-Agent': 'OpsFlood/3.3'},
        ).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final body  = jsonDecode(resp.body);
          final items = body is List ? body
              : (body['data'] as List? ?? body['stations'] as List? ?? []);
          for (final item in items) {
            final name = (item['site'] ?? item['station_name'] ?? '').toString().toLowerCase();
            if (!name.contains('birpur')) continue;
            final rawLevel = _parseDbl(item['current_level'] ?? item['water_level'] ?? item['wl']);
            // BEAMS reports in AMSL (>100 m) — convert to local gauge.
            final level = rawLevel != null && rawLevel > 100
                ? _amslToLocal(rawLevel)
                : rawLevel;  // already local if ≤100
            if (level != null) {
              final rawDl  = _parseDbl(item['danger_level']);
              final rawWl  = _parseDbl(item['warning_level']);
              final dl = (rawDl != null && rawDl > 100) ? (_amslToLocal(rawDl) ?? kBirpurDangerLevel)  : (rawDl  ?? kBirpurDangerLevel);
              final wl = (rawWl != null && rawWl > 100) ? (_amslToLocal(rawWl) ?? kBirpurWarningLevel) : (rawWl ?? kBirpurWarningLevel);
              debugPrint('[KosiBirpur] BEAMS-direct ✅ $level m (local gauge)');
              return KosiBirpurReading(
                levelM:       level,
                dangerLevel:  dl,
                warningLevel: wl,
                trend:        item['trend']?.toString(),
                observedAt:   DateTime.tryParse(item['observed_at']?.toString() ?? '') ?? DateTime.now(),
                source:       'BEAMS-direct',
              );
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // ── Source B: BefiqrCwcService ─────────────────────────────────────────────
  // CWC BeFIQR already returns local gauge datum for most stations.
  // For Birpur it also uses local datum (73.70/74.70), so no conversion needed.
  Future<KosiBirpurReading?> _tryFromCwcService() async {
    try {
      final stations = await _cwcSvc.fetchStations().timeout(const Duration(seconds: 12));
      final birpur   = stations.where((s) =>
          !s.isFromSeed &&
          s.river.toLowerCase().contains('kosi') &&
          s.site.toLowerCase().contains('birpur')).toList();
      if (birpur.isNotEmpty) {
        final s = birpur.first;
        // CWC BeFIQR: if level >100 it's AMSL, otherwise it's already local datum.
        final rawLevel = s.currentLevel;
        final level    = rawLevel > 100 ? (_amslToLocal(rawLevel) ?? rawLevel) : rawLevel;
        final rawDl    = s.dangerLevel;
        final dl       = rawDl > 100 ? (_amslToLocal(rawDl) ?? kBirpurDangerLevel) : rawDl;
        final rawWl    = s.warningLevel ?? kBirpurWarningLevel;
        final wl       = rawWl > 100 ? (_amslToLocal(rawWl) ?? kBirpurWarningLevel) : rawWl;
        debugPrint('[KosiBirpur] BefiqrCwc ✅ $level m local (raw ${s.currentLevel} from ${s.source})');
        return KosiBirpurReading(
          levelM:       level,
          dangerLevel:  dl,
          warningLevel: wl,
          trend:        s.trend,
          observedAt:   s.fetchedAt,
          source:       s.source,
        );
      }
    } catch (e) {
      debugPrint('[KosiBirpur] BefiqrCwc failed: $e');
    }
    return null;
  }

  // ── Source C: India-WRIS — AMSL, convert to local gauge ────────────────────
  Future<KosiBirpurReading?> _tryWRIS() async {
    final uris = [
      'https://indiawris.gov.in/WRIS/API/hydrograph?station_id=GD_00441&parameter=WL&days=1',
      'https://indiawris.gov.in/wris/api/v1/hydrograph?station_id=GD_00441&parameter=WL&duration=1',
      'https://indiawris.gov.in/WRIS/API/hydrograph?station_id=GD_00441&parameter=Q&days=1',
    ];
    for (final u in uris) {
      try {
        final resp = await _getNoLoop(
          u,
          headers: {'Accept': 'application/json', 'User-Agent': 'OpsFlood/3.3'},
          timeout: const Duration(seconds: 10),
        );
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          final list = (body['data'] as List? ?? body['hydrograph'] as List?);
          if (list != null && list.isNotEmpty) {
            final latest = list.last as Map<String, dynamic>;
            final val    = _parseDbl(latest['value'] ?? latest['wl'] ?? latest['level']);
            final obsAt  = DateTime.tryParse(
                latest['date']?.toString() ?? latest['time']?.toString() ?? '') ?? DateTime.now();
            if (val != null && val > 100) {
              // WRIS WL parameter — AMSL, convert.
              final local = _amslToLocal(val);
              if (local != null) {
                debugPrint('[KosiBirpur] WRIS WL ✅ $local m local (AMSL $val)');
                return KosiBirpurReading(
                  levelM:       local,
                  dangerLevel:  kBirpurDangerLevel,
                  warningLevel: kBirpurWarningLevel,
                  observedAt:   obsAt,
                  source:       'India-WRIS',
                );
              }
            }
            if (val != null && val > 0 && val <= 100) {
              // WRIS Q (discharge) parameter — derive level via rating curve.
              final h = _dischargeToLevel(val);
              debugPrint('[KosiBirpur] WRIS Q=$val → H=$h m local');
              return KosiBirpurReading(
                levelM:          h,
                dangerLevel:     kBirpurDangerLevel,
                warningLevel:    kBirpurWarningLevel,
                dischargeCumecs: val,
                observedAt:      obsAt,
                source:          'India-WRIS (Q→H)',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[KosiBirpur] WRIS[$u] failed: $e');
      }
    }
    return null;
  }

  // ── Source D/E: CWC FFS endpoints ─────────────────────────────────────────
  Future<KosiBirpurReading?> _tryFFSEndpoint(String url) async {
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'Referer':      'https://ffs.india-water.gov.in/',
          'User-Agent':   'Mozilla/5.0 (OpsFlood/3.3)',
        },
        body: jsonEncode({'station_id': 'BR-1', 'river': 'KOSI', 'state': 'BIHAR'}),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body  = jsonDecode(resp.body) as Map<String, dynamic>;
        final data  = body['data'] as Map<String, dynamic>? ?? body;
        final raw   = _parseDbl(
            data['current_level'] ?? data['gauge_level'] ??
            data['level']         ?? data['wl']);
        if (raw != null) {
          final level = raw > 100 ? _amslToLocal(raw) : raw;
          if (level != null) {
            final rawDl = _parseDbl(data['danger_level']);
            final dl    = rawDl != null
                ? (rawDl > 100 ? (_amslToLocal(rawDl) ?? kBirpurDangerLevel) : rawDl)
                : kBirpurDangerLevel;
            debugPrint('[KosiBirpur] FFS ✅ level=$level m local ($url)');
            return KosiBirpurReading(
              levelM:          level,
              dangerLevel:     dl,
              warningLevel:    kBirpurWarningLevel,
              dischargeCumecs: _parseDbl(data['discharge'] ?? data['q']),
              observedAt:      DateTime.now(),
              source:          'CWC-FFS',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[KosiBirpur] FFS[$url] skipped: $e');
    }
    return null;
  }

  // ── Seed (local gauge datum) ───────────────────────────────────────────────
  // 210.80 AMSL → 71.48 m local (normal pre-monsoon level)
  KosiBirpurReading _seed() {
    debugPrint('[KosiBirpur] ⚠️ all sources failed — SEED (71.48 m local)');
    return KosiBirpurReading(
      levelM:       71.48,
      dangerLevel:  kBirpurDangerLevel,
      warningLevel: kBirpurWarningLevel,
      observedAt:   DateTime(2026, 6, 1),
      source:       'SEED',
    );
  }

  // ── Utilities ────────────────────────────────────────────────────────────────
  /// Discharge → local gauge height via simple linear rating curve.
  /// Maps Q=0 → 65.0 m local, Q=kBirpurDangerDischarge → kBirpurDangerLevel.
  static double _dischargeToLevel(double q) {
    final ratio = (q / kBirpurDangerDischarge).clamp(0.0, 1.2);
    return 65.0 + (kBirpurDangerLevel - 65.0) * (ratio < 1 ? ratio : 1.0);
  }

  static double? _parseDbl(dynamic v) {
    if (v == null) return null;
    if (v is num)  return v.toDouble();
    return double.tryParse(
        v.toString().replaceAll(RegExp(r'[^\d.]'), '').trim());
  }
}
