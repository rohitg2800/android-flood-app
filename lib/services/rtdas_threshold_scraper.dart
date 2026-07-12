// lib/services/rtdas_threshold_scraper.dart
//
// Scrapes the WRD Bihar RTDAS station table for official
// Warning Level (WL), Danger Level (DL), and HFL values.
//
// SOURCE: irrigation.fmiscwrdbihar.gov.in/state/table/rtdas-stations
// (same page shown in the mobile app embed)
//
// RTDAS HTML table column layout (0-indexed, verified Jun 2026):
//   0  Sr#
//   1  Station Name
//   2  Station Type   (G = Gauge, D = Discharge, …)
//   3  Maintained By  (CWC / WRD)
//   4  Other Station ID
//   5  Year
//   6  HFL (m)
//   7  Danger Level (m)
//   8  Warning Level (m)
//
// UNIT ENCODING NOTE (discovered Jun 2026):
//   WRD Bihar RTDAS encodes some station thresholds in CENTIMETRES
//   (e.g. Birpur DL = 7470 meaning 74.70 m MSL, HFL = 7602 = 76.02 m).
//   _normaliseLevel() detects this automatically:
//     - Bihar river gauge levels are always in range [0, 200] m MSL
//     - Any raw value > 500 is treated as centimetres → divided by 100
//     - A sanity clamp [0, 200] is applied after conversion
//   This fixes the "Birpur showing 210 m" display bug.
//
// If WRD ever restructures the table, update _kColMap below — nothing else
// needs to change.
library;

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as htmlParser;
import 'package:flutter/foundation.dart';

class RtdasRow {
  final String station;
  final String? maintainedBy;
  final double? warningLevel;
  final double? dangerLevel;
  final double? hfl;

  const RtdasRow({
    required this.station,
    this.maintainedBy,
    this.warningLevel,
    this.dangerLevel,
    this.hfl,
  });

  @override
  String toString() =>
      'RtdasRow($station  WL=$warningLevel  DL=$dangerLevel  HFL=$hfl)';
}

class RtdasThresholdScraper {
  static const _primaryUrl =
      'https://irrigation.fmiscwrdbihar.gov.in/state/table/'
      'rtdas-stations?platform=mobileapp&hide=hamburger';

  // BeFIQR RTDAS mirror — used as fallback if primary is unreachable.
  static const _fallbackUrl =
      'https://beams.fmiscwrdbihar.gov.in/Alerttotalinfo/realtimetotal.aspx';

  // Column indices — update here only if WRD changes the table layout.
  static const _kColMap = (
    station: 1,
    maintainedBy: 3,
    hfl: 6,
    dangerLevel: 7,
    warningLevel: 8,
  );

  // Bihar river gauges are always in [0, 200] m MSL.
  // Any parsed value above this threshold is assumed to be in centimetres.
  static const _kCmThreshold = 500.0;
  static const _kMaxLevelM = 200.0;

  /// Fetch RTDAS rows, trying primary URL first then fallback.
  Future<List<RtdasRow>> fetch() async {
    try {
      return await _fetchFrom(_primaryUrl);
    } catch (e) {
      debugPrint('[RtdasScraper] primary failed ($e) — trying fallback …');
      return await _fetchFrom(_fallbackUrl);
    }
  }

  Future<List<RtdasRow>> _fetchFrom(String url) async {
    final res = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'OpsFlood/3 (Bihar Flood App; +github.com/rohitg2800)',
      'Accept': 'text/html,application/xhtml+xml',
    }).timeout(const Duration(seconds: 25));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} from $url');
    }

    final doc = htmlParser.parse(res.body);
    final rows = doc.querySelectorAll('table tbody tr');
    if (rows.isEmpty) throw Exception('No table rows found at $url');

    final result = <RtdasRow>[];

    for (final row in rows) {
      final cells =
          row.querySelectorAll('td').map((e) => e.text.trim()).toList();

      // Need at least 9 columns (indices 0-8)
      if (cells.length < 9) continue;

      final station = cells[_kColMap.station];
      if (station.isEmpty || station == 'Station Name') continue;

      final hfl = _normaliseLevel(_parse(cells[_kColMap.hfl]), 'HFL', station);
      final danger =
          _normaliseLevel(_parse(cells[_kColMap.dangerLevel]), 'DL', station);
      final warning =
          _normaliseLevel(_parse(cells[_kColMap.warningLevel]), 'WL', station);

      // Skip rows where all three are null (non-gauge entries)
      if (hfl == null && danger == null && warning == null) continue;

      result.add(RtdasRow(
        station: station,
        maintainedBy: cells[_kColMap.maintainedBy],
        warningLevel: warning,
        dangerLevel: danger,
        hfl: hfl,
      ));
    }

    debugPrint('[RtdasScraper] parsed ${result.length} rows from $url');
    return result;
  }

  // ── Unit normalisation ────────────────────────────────────────────────────
  //
  // WRD RTDAS encodes some stations in cm (raw value > 500).
  // Converts to metres and clamps to [0, 200] m MSL.
  //
  // Examples:
  //   7470.0  → 74.70 m  (Birpur DL)
  //   7602.0  → 76.02 m  (Birpur HFL)
  //   7370.0  → 73.70 m  (Birpur WL)
  //   48.60   → 48.60 m  (Gandhighat DL — already metres, untouched)
  //   4860.0  → 48.60 m  (same station if encoded as cm)
  static double? _normaliseLevel(double? raw, String label, String station) {
    if (raw == null) return null;
    double metres = raw;
    if (raw > _kCmThreshold) {
      metres = raw / 100.0;
      debugPrint(
          '[RtdasScraper] $station $label: $raw cm → ${metres.toStringAsFixed(2)} m');
    }
    // Sanity clamp: no Bihar gauge is above 200 m MSL
    if (metres < 0 || metres > _kMaxLevelM) {
      debugPrint(
          '[RtdasScraper] $station $label: $metres m out of range — discarded');
      return null;
    }
    return metres;
  }

  static double? _parse(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty || cleaned == '-' || cleaned == 'N/A') return null;
    return double.tryParse(cleaned);
  }
}
