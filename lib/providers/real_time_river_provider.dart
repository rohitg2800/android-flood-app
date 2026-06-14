// lib/providers/real_time_river_provider.dart  v8.7
//
// v8.7 (14 Jun 2026) — Fix Riverpod 3.x pausedActiveSubscriptionCount crash
//
//   ROOT CAUSE:
//   realTimeRiverProvider was FutureProvider.autoDispose.
//   mergedStationsProvider is a plain Provider (persistent) that watches it.
//   On a TickerMode change (navigation / screen off), autoDispose called
//   ref.invalidateSelf() while mergedStationsProvider held a paused
//   subscription → Riverpod 3.x asserted:
//     'Expected pausedActiveSubscriptionCount to be 1, but was 2'
//
//   FIX: plain FutureProvider (non-autoDispose) + ref.keepAlive().
//   A provider watched by a persistent parent Provider must never autoDispose.
//
// v8.6 (13 Jun 2026) — current-level plausibility guard for Birpur
//   _birpurLevelPlausible: level > 0 && level <= 80 m.
//   Birpur gauge ~74 m MSL; HFL 76.02 m. Anything > 80 m is a discharge
//   value mis-read as water level → fall through to SEED sentinel.
//
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import '../services/wrd_bihar_service.dart';
import '../services/befiqr_cwc_service.dart';
import 'station_history_provider.dart';
import 'cwc_provider.dart';
import 'data_fetch_provider.dart';
import 'kosi_birpur_provider.dart';
import 'live_engine_bridge_provider.dart';

// ───────────────────────────────────────────────────────────────────────────────────
// Bihar state filter
// ───────────────────────────────────────────────────────────────────────────────────
const _kBiharAliases = {'bihar', 'br', 'state of bihar'};
bool _isBihar(String state) =>
    _kBiharAliases.contains(state.toLowerCase().trim());

// ───────────────────────────────────────────────────────────────────────────────────
// Name normalisation helpers
// ───────────────────────────────────────────────────────────────────────────────────

String _normBase(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _normFull(String s) => s.toLowerCase().trim();

String _norm(String s) => _normBase(s);

bool _sameStation(String a, String b) {
  final hasQualA = a.contains('(');
  final hasQualB = b.contains('(');
  if (hasQualA && hasQualB) {
    return _normFull(a) == _normFull(b);
  }
  return _normBase(a) == _normBase(b);
}

bool _isBirpur(String name) =>
    name.toLowerCase().contains('birpur');

const double _kBirpurWarning = 73.70;
const double _kBirpurDanger  = 74.70;
const double _kBirpurHfl     = 76.02;

/// v8.6: current-level guard — Birpur is ~74 m MSL, HFL 76.02 m.
/// Any reading above 80 m is a discharge value mis-read as water level.
bool _birpurLevelPlausible(double level) => level > 0.0 && level <= 80.0;

/// v8.5: danger-level guard for DataFetch fallback rows.
/// Birpur danger level is 74.70 m.  Anything above 90 m is a blowout.
bool _birpurDlPlausible(double dl) => dl >= 50.0 && dl <= 90.0;

// ───────────────────────────────────────────────────────────────────────────────────
// 1. Raw WrdStation list
// ───────────────────────────────────────────────────────────────────────────────────
class WrdStationsNotifier extends AsyncNotifier<List<WrdStation>> {
  static const _refreshInterval = Duration(minutes: 15);
  Timer? _timer;

  @override
  Future<List<WrdStation>> build() async {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(_refreshInterval, (_) => _refresh());
    return _doFetch();
  }

  Future<List<WrdStation>> _doFetch() =>
      WrdBiharService.instance.fetch();

  Future<void> _refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => WrdBiharService.instance.fetch(forceRefresh: true));
  }

  Future<void> forceRefresh() => _refresh();
}

final wrdStationsProvider =
    AsyncNotifierProvider<WrdStationsNotifier, List<WrdStation>>(
        WrdStationsNotifier.new);

// ───────────────────────────────────────────────────────────────────────────────────
// 2. WrdStation → RiverStation adapter
// ───────────────────────────────────────────────────────────────────────────────────
RiverStation _wrdToRiverStation(WrdStation s) {
  final cur = s.currentLevel ?? 0.0;
  final dl  = s.dangerLevel  ?? 0.0;
  final wl  = s.warningLevel ?? (dl > 0 ? dl - 1.0 : 0.0);
  final hfl = s.hfl          ?? (dl > 0 ? dl + 1.5 : 0.0);
  return RiverStation(
    city:        s.site,
    state:       'Bihar',
    river:       s.river,
    station:     s.site,
    current:     cur,
    warning:     wl,
    danger:      dl,
    hfl:         hfl,
    dataSource:  s.source,
    lastUpdated:
        '${s.fetchedAt.hour.toString().padLeft(2, '0')}:'
        '${s.fetchedAt.minute.toString().padLeft(2, '0')}',
    isLive: s.source == 'WRD_BIHAR_LIVE',
  );
}

RiverStation _cwcToRiverStation(CwcStation s) => RiverStation(
  city:        s.site,
  state:       'Bihar',
  river:       s.river,
  station:     s.site,
  current:     s.currentLevel,
  warning:     s.warningLevel ?? (s.dangerLevel - 1.5).clamp(0, double.infinity),
  danger:      s.dangerLevel,
  hfl:         s.dangerLevel + 1.5,
  dataSource:  s.source,
  lastUpdated: '${s.fetchedAt.hour.toString().padLeft(2, '0')}:'
               '${s.fetchedAt.minute.toString().padLeft(2, '0')}',
  isLive:      !s.isFromSeed,
);

final wrdRiverStationsProvider =
    Provider<AsyncValue<List<RiverStation>>>((ref) {
  return ref.watch(wrdStationsProvider).whenData(
    (raw) => raw.map(_wrdToRiverStation).toList(),
  );
});

// ───────────────────────────────────────────────────────────────────────────────────
// 3. realTimeRiverProvider — WRD-only alias for map screen
//
// v8.7: MUST NOT be autoDispose.
//   mergedStationsProvider (plain Provider, persistent) watches this provider.
//   If this provider auto-disposes while mergedStationsProvider holds a paused
//   subscription, Riverpod 3.x asserts pausedActiveSubscriptionCount mismatch.
//   Fix: plain FutureProvider + ref.keepAlive().
// ───────────────────────────────────────────────────────────────────────────────────
final realTimeRiverProvider =
    FutureProvider<List<RiverStation>>((ref) async {
  // v8.7: must never auto-dispose — watched by persistent mergedStationsProvider.
  ref.keepAlive();

  final async = ref.watch(wrdStationsProvider);

  if (async.isLoading || async.asData?.value == null) {
    final cached = WrdBiharService.instance.cachedStations;
    if (cached != null && cached.isNotEmpty) {
      return cached.map(_wrdToRiverStation).toList();
    }
  }

  final stations  = async.asData?.value ?? [];
  final converted = stations.map(_wrdToRiverStation).toList();
  ref.read(stationHistoryProvider.notifier).pushSnapshot(converted);

  if (kDebugMode) {
    debugPrint('[RealTimeRiver] ${converted.length} WRD stations forwarded');
  }
  return converted;
});

// ───────────────────────────────────────────────────────────────────────────────────
// 4. mergedStationsProvider — THE single source of truth
//
// v8.6: added _birpurLevelPlausible check on the kosiBirpurProvider branch.
//       If levelM > 80 m (discharge mis-read as water level), fall through
//       to the SEED sentinel (current=0.0) instead of showing 210/212 m.
// v8.5: birpurReading is nullable (KosiBirpurReading? from v2.1).
//       _birpurDlPlausible upper bound tightened 200 → 90 m.
// ───────────────────────────────────────────────────────────────────────────────────
final mergedStationsProvider = Provider<List<RiverStation>>((ref) {
  final _allLiveEngineRS = ref.watch(liveEngineStationsProvider);
  final liveEngineRS     = _allLiveEngineRS
      .where((s) => !_isBirpur(s.station))
      .toList();
  final liveEngineNames  = { for (final s in liveEngineRS) _normFull(s.station) };

  final wrdAsync    = ref.watch(realTimeRiverProvider);
  final cwcAsync    = ref.watch(cwcStationsProvider);
  final birpurAsync = ref.watch(kosiBirpurProvider); // KosiBirpurReading?

  List<RiverStation> wrdList;
  if (wrdAsync.isLoading || wrdAsync.asData?.value == null) {
    final cached = WrdBiharService.instance.cachedStations;
    wrdList = (cached ?? []).map(_wrdToRiverStation).toList();
  } else {
    wrdList = wrdAsync.asData!.value;
  }

  // ── Birpur entry (v8.6: level plausibility guard added) ─────────────────
  final RiverStation birpurStation;
  final birpurReading = birpurAsync.asData?.value; // KosiBirpurReading?

  final bool readingPlausible =
      birpurReading != null && _birpurLevelPlausible(birpurReading.levelM);

  if (readingPlausible) {
    birpurStation = RiverStation(
      city:        'Birpur',
      state:       'Bihar',
      river:       'Kosi',
      station:     'Birpur',
      current:     birpurReading!.levelM,
      warning:     birpurReading.warningLevel,
      danger:      birpurReading.dangerLevel,
      hfl:         birpurReading.dangerLevel + 1.5,
      dataSource:  birpurReading.source,
      lastUpdated:
          '${birpurReading.observedAt.hour.toString().padLeft(2, '0')}:'
          '${birpurReading.observedAt.minute.toString().padLeft(2, '0')}',
      isLive: birpurReading.source != 'SEED',
    );
  } else {
    if (birpurReading != null && !_birpurLevelPlausible(birpurReading.levelM)) {
      if (kDebugMode) {
        debugPrint(
          '[Birpur v8.6] rejected implausible level '
          '${birpurReading.levelM.toStringAsFixed(2)} m '
          '(source=${birpurReading.source}); falling back to DataFetch/SEED',
        );
      }
    }

    final dfBirpur = ref.watch(dataFetchStationsProvider)
        .where((s) =>
            _isBirpur(s.station) &&
            _birpurDlPlausible(s.danger) &&
            _birpurLevelPlausible(s.current))
        .firstOrNull;

    birpurStation = dfBirpur ?? RiverStation(
      city:        'Birpur',
      state:       'Bihar',
      river:       'Kosi',
      station:     'Birpur',
      current:     0.0,
      warning:     _kBirpurWarning,
      danger:      _kBirpurDanger,
      hfl:         _kBirpurHfl,
      dataSource:  'SEED',
      lastUpdated: '--:--',
      isLive:      false,
    );
  }

  final allCwcStations = cwcAsync.asData?.value ?? const <CwcStation>[];
  final cwcLive = allCwcStations
      .where((s) => !s.isFromSeed && !_isBirpur(s.site)).toList();
  final cwcSeed = allCwcStations
      .where((s) =>  s.isFromSeed && !_isBirpur(s.site)).toList();

  final cwcLiveRS    = cwcLive.map(_cwcToRiverStation).toList();
  final cwcSeedRS    = cwcSeed.map(_cwcToRiverStation).toList();
  final cwcLiveNames = { for (final s in cwcLiveRS) _normFull(s.station) };

  final allDfStations = ref.watch(dataFetchStationsProvider);
  final dfStations = allDfStations
      .where((s) =>
          _isBihar(s.state) &&
          !_isBirpur(s.station) &&
          !liveEngineNames.any((n) => _sameStation(n, s.station)) &&
          !cwcLiveNames.any((n) => _sameStation(n, s.station)))
      .toList();

  if (kDebugMode && allDfStations.length != dfStations.length) {
    debugPrint(
      '[Merged v8.7] dropped ${allDfStations.length - dfStations.length} '
      'non-Bihar/duplicate stations from DataFetch tier',
    );
  }

  final dfNames = { for (final s in dfStations) _normFull(s.station) };

  final wrdFiltered = wrdList
      .where((s) =>
          !_isBirpur(s.station) &&
          !liveEngineNames.any((n) => _sameStation(n, s.station)) &&
          !cwcLiveNames.any((n) => _sameStation(n, s.station)) &&
          !dfNames.any((n) => _sameStation(n, s.station)))
      .toList();
  final wrdNames = { for (final s in wrdFiltered) _normFull(s.station) };

  final cwcSeedFiltered = cwcSeedRS
      .where((s) =>
          !liveEngineNames.any((n) => _sameStation(n, s.station)) &&
          !cwcLiveNames.any((n) => _sameStation(n, s.station)) &&
          !dfNames.any((n) => _sameStation(n, s.station)) &&
          !wrdNames.any((n) => _sameStation(n, s.station)))
      .toList();

  final merged = [
    ...liveEngineRS,
    ...cwcLiveRS,
    ...dfStations,
    ...wrdFiltered,
    ...cwcSeedFiltered,
    birpurStation,
  ];
  merged.sort((a, b) => b.riskScore.compareTo(a.riskScore));

  if (kDebugMode) {
    debugPrint(
      '[Merged v8.7] ${liveEngineRS.length} LiveEngine'
      ' + ${cwcLiveRS.length} CWC-live'
      ' + ${cwcSeedFiltered.length} CWC-seed'
      ' + ${dfStations.length} DataFetch(Bihar)'
      ' + ${wrdFiltered.length} WRD'
      ' + 1 Birpur (level=${birpurStation.current.toStringAsFixed(2)} DL=${birpurStation.danger})'
      ' = ${merged.length} total',
    );
  }
  return merged;
});

// ───────────────────────────────────────────────────────────────────────────────────
// 5. Count providers
// ───────────────────────────────────────────────────────────────────────────────────

final mergedTotalCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider).length);

final mergedExtremeCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.dangerClass == DangerClass.extreme)
        .length);

final mergedCriticalCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) =>
            s.dangerClass == DangerClass.severe ||
            s.dangerClass == DangerClass.extreme)
        .length);

final mergedElevatedCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.dangerClass == DangerClass.aboveNormal)
        .length);

final mergedNormalCountProvider = Provider<int>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.dangerClass == DangerClass.normal)
        .length);

final mergedBiharStationsProvider = Provider<List<RiverStation>>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.state.toLowerCase().contains('bihar'))
        .toList());

// ───────────────────────────────────────────────────────────────────────────────────
// 6. Legacy convenience providers
// ───────────────────────────────────────────────────────────────────────────────────

final wrdStationCountProvider = Provider<int>((ref) {
  final async = ref.watch(wrdStationsProvider);
  return async.asData?.value.length ?? 0;
});

final wrdCriticalStationsProvider = Provider<List<RiverStation>>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) =>
            s.dangerClass == DangerClass.extreme ||
            s.dangerClass == DangerClass.severe)
        .toList());

final wrdWarningStationsProvider = Provider<List<RiverStation>>((ref) =>
    ref.watch(mergedStationsProvider)
        .where((s) => s.dangerClass == DangerClass.aboveNormal)
        .toList());

final wrdByRiverProvider = Provider<Map<String, List<RiverStation>>>((ref) {
  final list = ref.watch(mergedStationsProvider);
  final map  = <String, List<RiverStation>>{};
  for (final s in list) {
    map.putIfAbsent(s.river, () => []).add(s);
  }
  for (final v in map.values) {
    v.sort((a, b) => b.riskScore.compareTo(a.riskScore));
  }
  return map;
});

final wrdIsLoadingProvider = Provider<bool>((ref) =>
    ref.watch(wrdStationsProvider).isLoading);

final wrdErrorProvider = Provider<String?>((ref) {
  final async = ref.watch(wrdStationsProvider);
  return async.hasError ? async.error.toString() : null;
});

final wrdIsLiveProvider = Provider<bool>((ref) {
  final async = ref.watch(wrdStationsProvider);
  final list  = async.asData?.value ?? [];
  return list.any((s) => s.source == 'WRD_BIHAR_LIVE');
});
