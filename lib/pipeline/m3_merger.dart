// lib/pipeline/m3_merger.dart
//
// MODULE 3 — Merger / Deduplicator
// Collapses multi-source records for the same gauge into one FloodRecord.
// Priority: WRD_BIHAR(10) > KOSI(9) > CWC(8) > BEFIQR(7) > BACKEND(5) > GLOFAS(4)

library pipeline.merger;

import 'package:flutter/foundation.dart';
import 'm0_canonical_model.dart';

class Merger {
  Merger._();
  static final Merger instance = Merger._();

  List<FloodRecord> merge(List<FloodRecord> records) {
    final groups = <String, List<FloodRecord>>{};
    for (final r in records) {
      groups.putIfAbsent(r.stationKey, () => []).add(r);
    }
    final merged    = <FloodRecord>[];
    var   conflicts = 0;
    for (final entry in groups.entries) {
      final group = entry.value;
      if (group.length == 1) { merged.add(group.first); continue; }
      conflicts++;
      group.sort((a, b) {
        final pCmp = b.source.priority.compareTo(a.source.priority);
        if (pCmp != 0) return pCmp;
        return b.fetchedAt.compareTo(a.fetchedAt);
      });
      var champion = group.first;
      for (var i = 1; i < group.length; i++) champion = champion.mergeWith(group[i]);
      merged.add(champion);
    }
    debugPrint('[M3:Merger] in=\${records.length}  out=\${merged.length}  conflicts_resolved=$conflicts');
    return merged;
  }
}
