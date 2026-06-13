// lib/providers/river_station_family_provider.dart
//
// fix (2026-06-13): The backward-compat `export` directive at the bottom was
// placed after the `riverStationProvider` declaration — Dart forbids directives
// after any declaration in the same library. Moved the export to the top of
// the directive block, before all code.
//
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import 'kosi_birpur_provider.dart' show kosiBirpurProvider, KosiBirpurReading;
import 'real_time_river_provider.dart' show mergedStationsProvider;

// Backward-compat re-export — MUST appear before any declarations.
export 'kosi_birpur_provider.dart' show
    kosiBirpurProvider,
    kosiBirpurStationProvider,
    cwcStationsWithBirpurProvider,
    kosiStationsProvider,
    birpurBadgeProvider,
    BirpurBadge;

// ─────────────────────────────────────────────────────────────────────────────
// Station identifier enum
// ─────────────────────────────────────────────────────────────────────────────
enum StationId {
  // Ganga basin
  gandhighat,
  dighaghat,
  hathidah,
  munger,
  kahalgaon,
  bhagalpur,
  buxar,
  // Kosi basin
  kosiBirpur,
  baltara,
  basua,
  kursela,
  // Gandak basin
  chatia,
  dumariaghat,
  rewaghat,
  hajipur,
  // Bagmati basin
  dhengBridge,
  benibad,
  hayaghat,
  // Burhi Gandak basin
  sikandarpur,
  samastipur,
  rosera,
  khagaria,
  // Ghaghra basin
  darauli,
  gangpurSiswan,
  // Mahananda basin
  dhengraghat,
  taibpur,
  // Minor rivers
  jainagar,
  jhanjharpur,
  sonbarsa,
  kamtaul,
  sripalpur;

  String get stationName => switch (this) {
    StationId.gandhighat    => 'Gandhighat',
    StationId.dighaghat     => 'Dighaghat',
    StationId.hathidah      => 'Hathidah',
    StationId.munger        => 'Munger',
    StationId.kahalgaon     => 'Kahalgaon',
    StationId.bhagalpur     => 'Bhagalpur',
    StationId.buxar         => 'Buxar',
    StationId.kosiBirpur    => 'Birpur (CWC)',
    StationId.baltara       => 'Baltara',
    StationId.basua         => 'Basua',
    StationId.kursela       => 'Kursela',
    StationId.chatia        => 'Chatia',
    StationId.dumariaghat   => 'Dumariaghat',
    StationId.rewaghat      => 'Rewaghat',
    StationId.hajipur       => 'Hajipur',
    StationId.dhengBridge   => 'Dheng Bridge',
    StationId.benibad       => 'Benibad',
    StationId.hayaghat      => 'Hayaghat',
    StationId.sikandarpur   => 'Sikandarpur',
    StationId.samastipur    => 'Samastipur',
    StationId.rosera        => 'Rosera',
    StationId.khagaria      => 'Khagaria',
    StationId.darauli       => 'Darauli',
    StationId.gangpurSiswan => 'Gangpur Siswan',
    StationId.dhengraghat   => 'Dhengraghat',
    StationId.taibpur       => 'Taibpur',
    StationId.jainagar      => 'Jainagar',
    StationId.jhanjharpur   => 'Jhanjharpur',
    StationId.sonbarsa      => 'Sonbarsa',
    StationId.kamtaul       => 'Kamtaul',
    StationId.sripalpur     => 'Sripalpur',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// riverStationProvider — parameterised family
// ─────────────────────────────────────────────────────────────────────────────
final riverStationProvider = FutureProvider.autoDispose
    .family<RiverStation?, StationId>((ref, id) async {
  if (id == StationId.kosiBirpur) {
    final reading = await ref.watch(kosiBirpurProvider.future);
    return RiverStation(
      city:        'Birpur',
      state:       'Bihar',
      river:       'Kosi',
      station:     'Birpur',
      current:     reading.levelM,
      warning:     reading.warningLevel,
      danger:      reading.dangerLevel,
      hfl:         reading.dangerLevel + 1.5,
      dataSource:  reading.source,
      lastUpdated:
          '${reading.observedAt.hour.toString().padLeft(2, '0')}:'
          '${reading.observedAt.minute.toString().padLeft(2, '0')}',
      isLive: reading.source != 'SEED',
    );
  }

  final merged = ref.watch(mergedStationsProvider);
  final name   = id.stationName.toLowerCase();
  return merged
      .where((s) => s.station.toLowerCase().contains(name) ||
                    name.contains(s.station.toLowerCase()))
      .firstOrNull;
});
