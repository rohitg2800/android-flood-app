// lib/services/kosi_birpur_service.dart  v3.4
//
// v3.4 (15 Jun 2026) — Bihar pipeline fix:
//   The WRIS server redirects /WRIS/API/hydrograph → /wriswriswrisWRIS/API/...
//   _getNoLoop() correctly detected the loop (isLoop=true) but then returned
//   the raw 302 response.  _tryWRIS() then failed the statusCode==200 check
//   silently and fell to seed.
//
//   Fix:
//   1. _getNoLoop() now returns null (not the 302) when a loop is detected,
//      which lets _tryWRIS() skip cleanly via the null-guard.
//   2. _tryWRIS() adds a content-type + JSON prefix guard before jsonDecode
//      so HTML error pages never reach the parser.
//   3. Redirects to a DIFFERENT path (non-loop) are still followed once.
//
// v3.3: Datum conversion AMSL → local gauge (139.32 m offset).
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
const double kBirpurDatumOffset      = 139.32;
const double kBirpurDangerLevel      =  74.70;
const double kBirpurWarningLevel     =  73.70;
const double kBirpurNormalLevel      =  71.48;
const double kBirpurHFL              =  76.02;
const double kBirpurWarningDischarge = 22000.0;
const double kBirpurDangerDischarge  = 27014.0;

// ─────────────────────────────────────────────────────────────────────────────
class KosiBirpurReading {
  final double  levelM;
  final double  dangerLevel;
  final double  warningLevel;
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
double? _amslToLocal(double? amsl) {
  if (amsl == null) return null;
  final local = amsl - kBirpurDatumOffset;
  if (local < 50 || local > 90) return null;
  return local;
}

// ── HTTP client that does NOT follow redirects ─────────────────────────────
http.Client _noRedirectClient() {
  final inner = HttpClient()..maxConnectionsPerHost = 4;
  inner.findProxy = null;
  return IOClient(inner);
}

/// Performs a GET without auto-following redirects.
/// Returns null if a redirect loop is detected.
/// Returns the response on 200 or after one clean redirect.
Future<http.Response?> _getNoLoop(
  String url, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final client = _noRedirectClient();
  try {
    final req    = http.Request('GET', Uri.parse(url));
    if (headers != null) req.headers.addAll(headers);
    final stream = await client.send(req).timeout(timeout);
    var resp     = await http.Response.fromStream(stream);

    if (resp.statusCode >= 300 && resp.statusCode < 400) {
      final loc = resp.headers['location'];
      if (loc == null) return null; // no Location header — give up

      final origPath  = Uri.parse(url).path.toLowerCase();
      final redirPath = Uri.parse(loc).path.toLowerCase();

      // ── v3.4 fix: return null on loop (was returning the 302) ──────
      final isLoop = redirPath.contains(origPath) && redirPath != origPath;
      if (isLoop) {
        debugPrint('[WRIS] redirect loop detected — aborting: $loc');
        return null; // caller skips this URL cleanly
      }
      // ── follow one clean redirect ──────────────────────────────────
      final req2    = http.Request('GET', Uri.parse(loc));
      if (headers != null) req2.headers.addAll(headers);
      final stream2 = await client.send(req2).timeout(timeout);
      resp = await http.Response.fromStream(stream2);
    }
    return resp;
  } catch (e) {
    debugPrint('[WRIS] _getNoLoop error ($url): $e');
    return null;
  } finally {
    client.close();
  }
}

// ── KosiBirpurService ──────────────────────────────────────────────────────

class KosiBirpurService {
  static const _raceTimeout = Duration(seconds: 13);
  final BefiqrCwcService _cwcSvc = BefiqrCwcService();

  Future<KosiBirpurReading?> fetchLive() async {
    // v3.5: CWC is the authoritative source (same as bihar_live_provider).
    // Try it first synchronously — only race fallbacks if CWC returns null.
    final cwc = await _tryFromCwcService().timeout(
        const Duration(seconds: 13), onTimeout: () => null);
    if (cwc != null) {
      debugPrint('[KosiBirpur] fetchLive ✅ CWC preferred: \${cwc.levelM} m');
      return cwc;
    }

    // CWC unavailable — race remaining sources.
    final futures = <Future<KosiBirpurReading?>>[
      _tryBeamsDirect(),
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
    return result; // v2.2: no seed fallback — let provider handle null
  }

  // ── Source A: BEAMS Bihar direct JSON ──────────────────────────────────────
  Future<KosiBirpurReading?> _tryBeamsDirect() async {
    final urls = [
      'https://api.beams.bihar.gov.in/api/stations/live?river=KOSI&site=BIRPUR',
      'https://api.beams.bihar.gov.in/public/flood/stations?river=kosi',
    ];
    for (final url in urls) {
      try {
        final resp = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json', 'User-Agent': 'OpsFlood/3.4'},
        ).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200 && _isJsonBody(resp.body)) {
          final body  = jsonDecode(resp.body);
          final items = body is List ? body
              : (body['data'] as List? ?? body['stations'] as List? ?? []);
          for (final item in items) {
            final name = (item['site'] ?? item['station_name'] ?? '').toString().toLowerCase();
            if (!name.contains('birpur')) continue;
            final rawLevel = _parseDbl(item['current_level'] ?? item['water_level'] ?? item['wl']);
            final level = rawLevel != null && rawLevel > 100
                ? _amslToLocal(rawLevel)
                : rawLevel;
            if (level != null) {
              final rawDl = _parseDbl(item['danger_level']);
              final rawWl = _parseDbl(item['warning_level']);
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
  Future<KosiBirpurReading?> _tryFromCwcService() async {
    try {
      final stations = await _cwcSvc.fetchStations().timeout(const Duration(seconds: 12));
      final birpur   = stations.where((s) =>
          !s.isFromSeed &&
          s.river.toLowerCase().contains('kosi') &&
          s.site.toLowerCase().contains('birpur')).toList();
      if (birpur.isNotEmpty) {
        final s        = birpur.first;
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

  // ── Source C: India-WRIS ───────────────────────────────────────────────────
  // v3.4: _getNoLoop now returns null on redirect loop (not 302).
  //       Added _isJsonBody guard before jsonDecode.
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
          headers: {'Accept': 'application/json', 'User-Agent': 'OpsFlood/3.4'},
          timeout: const Duration(seconds: 10),
        );
        // v3.4: resp is null on loop — skip cleanly.
        if (resp == null) {
          debugPrint('[KosiBirpur] WRIS[$u] loop/null — skipping');
          continue;
        }
        // v3.4: guard HTML error pages.
        if (resp.statusCode != 200 || !_isJsonBody(resp.body)) {
          debugPrint('[KosiBirpur] WRIS[$u] status=${resp.statusCode}, non-JSON — skipping');
          continue;
        }
        final body = jsonDecode(resp.body);
        final list = (body['data'] as List? ?? body['hydrograph'] as List?);
        if (list != null && list.isNotEmpty) {
          final latest = list.last as Map<String, dynamic>;
          final val    = _parseDbl(latest['value'] ?? latest['wl'] ?? latest['level']);
          final obsAt  = DateTime.tryParse(
              latest['date']?.toString() ?? latest['time']?.toString() ?? '') ?? DateTime.now();
          if (val != null && val > 100) {
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
          'User-Agent':   'Mozilla/5.0 (OpsFlood/3.4)',
        },
        body: jsonEncode({'station_id': 'BR-1', 'river': 'KOSI', 'state': 'BIHAR'}),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && _isJsonBody(resp.body)) {
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


  // ── Utilities ─────────────────────────────────────────────────────────────
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

// ── JSON body guard (shared by all sources in this file) ──────────────────
bool _isJsonBody(String body) {
  final t = body.trimLeft();
  return t.startsWith('{') || t.startsWith('[');
}
