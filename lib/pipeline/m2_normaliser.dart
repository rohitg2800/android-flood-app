// lib/pipeline/m2_normaliser.dart
//
// MODULE 2 — Normaliser
// Validates and deduplicates records within a single source.

library pipeline.normaliser;

import 'package:flutter/foundation.dart';
import 'm0_canonical_model.dart';
import 'm1_source_registry.dart';

class Normaliser {
  Normaliser._();
  static final Normaliser instance = Normaliser._();

  List<FloodRecord> normalise(List<SourceResult> results) {
    final seen    = <String>{};
    final clean   = <FloodRecord>[];
    var   dropped = 0;
    for (final result in results) {
      for (final record in result.records) {
        if (record.stationKey.isEmpty || record.stationName.isEmpty) { dropped++; continue; }
        final withinKey = '\${result.sourceName}:\${record.stationKey}';
        if (seen.contains(withinKey)) { dropped++; continue; }
        seen.add(withinKey);
        clean.add(record);
      }
    }
    if (dropped > 0) debugPrint('[M2:Normaliser] dropped $dropped invalid/dup rows');
    debugPrint('[M2:Normaliser] clean=\${clean.length} from \${results.length} sources');
    return clean;
  }
}
