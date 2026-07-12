// lib/providers/map_command_provider.dart  v1.2
//
// v1.2 (14 Jun 2026) — Fix Riverpod 3.x pausedActiveSubscriptionCount=3 crash
//
//   CRASH:
//     Expected pausedActiveSubscriptionCount to be 2, but was 3.
//     ProviderElement<List<RiverStation>> (origin: mapStationsProvider)
//
//   ROOT CAUSE:
//     biharDistrictRiskProvider (autoDispose) was watching mapStationsProvider
//     (autoDispose).  On a TickerMode change, Riverpod 3.x's
//     ConsumerStatefulElement._updateTickerMode resumed the 2 expected
//     ProviderContainer subscriptions to mapStationsProvider, but
//     biharDistrictRiskProvider's provider→provider sub was also resumed
//     during the same flush cycle → 3 resumes vs expected 2 → assertion crash.
//
//   FIX:
//     biharDistrictRiskProvider now watches mergedStationsProvider (persistent)
//     and mapViewModeProvider (persistent) directly — no autoDispose chain.
//     mapStationsProvider retains exactly 2 ProviderContainer listeners
//     while the map screen is open, so TickerMode always sees count=2.
//
// v1.1 (14 Jun 2026) — Convert mapStationsProvider + biharDistrictRiskProvider
//   to Provider.autoDispose to fix previous pausedActiveSubscriptionCount crash.
//
// v1.0: initial

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/cwc_provider.dart';
import '../services/befiqr_cwc_service.dart';

export 'cwc_provider.dart' show biharGeoJsonProvider;

// ─── View-mode toggle ───────────────────────────────────────────────────
enum MapViewMode { bihar, national }

class MapViewModeNotifier extends Notifier<MapViewMode> {
  @override
  MapViewMode build() => MapViewMode.bihar;

  void set(MapViewMode mode) => state = mode;
}

final mapViewModeProvider =
    NotifierProvider<MapViewModeNotifier, MapViewMode>(MapViewModeNotifier.new);

// ─── Selected station (popup) ─────────────────────────────────────────────
class SelectedStationNotifier extends Notifier<RiverStation?> {
  @override
  RiverStation? build() => null;

  void set(RiverStation? station) => state = station;
}

final mapSelectedStationProvider =
    NotifierProvider<SelectedStationNotifier, RiverStation?>(
        SelectedStationNotifier.new);

// ─── Sync metadata ────────────────────────────────────────────────────────────
class SyncMeta {
  final DateTime? cwcUpdated;
  final DateTime? wrdUpdated;
  final DateTime? gloFasUpdated;

  const SyncMeta({
    this.cwcUpdated,
    this.wrdUpdated,
    this.gloFasUpdated,
  });

  String get freshnessLabel {
    final times = <DateTime>[
      if (cwcUpdated != null) cwcUpdated!,
      if (wrdUpdated != null) wrdUpdated!,
      if (gloFasUpdated != null) gloFasUpdated!,
    ];
    if (times.isEmpty) return 'No data yet';
    times.sort();
    final diff = DateTime.now().difference(times.last);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  String labelFor(String source) {
    switch (source) {
      case 'CWC_FFEM':
        return cwcUpdated == null ? '—' : _fmt(cwcUpdated!);
      case 'WRD_BIHAR':
        return wrdUpdated == null ? '—' : _fmt(wrdUpdated!);
      case 'GLOFAS':
        return gloFasUpdated == null ? '—' : _fmt(gloFasUpdated!);
      default:
        return '—';
    }
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}  '
      '${t.day}/${t.month}';
}

class SyncMetaNotifier extends Notifier<SyncMeta> {
  @override
  SyncMeta build() => const SyncMeta();
}

final mapSyncMetaProvider =
    NotifierProvider<SyncMetaNotifier, SyncMeta>(SyncMetaNotifier.new);

// ─── CwcStation → RiverStation adapter ───────────────────────────────────────────
extension CwcStationAdapter on CwcStation {
  RiverStation toRiverStation() => RiverStation(
        city: site,
        state: 'Bihar',
        river: river,
        station: site,
        current: currentLevel,
        warning: (dangerLevel - 1.5).clamp(0, double.infinity),
        danger: dangerLevel,
        hfl: dangerLevel + 1.5,
        dataSource: 'CWC_FFEM',
        lastUpdated: '${fetchedAt.hour.toString().padLeft(2, '0')}:'
            '${fetchedAt.minute.toString().padLeft(2, '0')}',
        isLive: true,
      );
}

// ─── Gauge-site → Bihar district lookup ──────────────────────────────────────────
const Map<String, String> _kSiteToDistrict = {
  'ekmighat': 'darbhanga',
  'kamtaul': 'darbhanga',
  'sonbarsa': 'sitamarhi',
  'benibad': 'darbhanga',
  'dheng bridge': 'muzaffarpur',
  'dhengbridge': 'muzaffarpur',
  'hayaghat': 'darbhanga',
  'runnisaidpur': 'sitamarhi',
  'pupri': 'sitamarhi',
  'lalbakeya': 'sitamarhi',
  'donar': 'sitamarhi',
  'khagaria': 'khagaria',
  'rosera': 'samastipur',
  'samastipur': 'samastipur',
  'sikandarpur': 'muzaffarpur',
  'gaighat': 'muzaffarpur',
  'chatia': 'east champaran',
  'dumariaghat': 'west champaran',
  'hajipur': 'vaishali',
  'rewaghat': 'saran',
  'balmikinagar': 'west champaran',
  'balmiki nagar': 'west champaran',
  'turkaulia': 'west champaran',
  'sikta': 'west champaran',
  'bhitaha': 'west champaran',
  'bagaha': 'west champaran',
  'lauriya': 'west champaran',
  'motihari': 'east champaran',
  'areraj': 'east champaran',
  'bhagalpur': 'bhagalpur',
  'buxar': 'buxar',
  'dighaghat': 'patna',
  'gandhighat': 'patna',
  'hathidah': 'begusarai',
  'kahalgaon': 'bhagalpur',
  'munger': 'munger',
  'naugachia': 'bhagalpur',
  'darauli': 'saran',
  'gangpur siswan': 'siwan',
  'gangpur': 'siwan',
  'jhanjharpur': 'madhubani',
  'jainagar': 'madhubani',
  'phulparas': 'madhubani',
  'nirmali': 'supaul',
  'baltara': 'khagaria',
  'basua': 'supaul',
  'birpur': 'supaul',
  'kursela': 'katihar',
  'bhim nagar': 'supaul',
  'bhimnagar': 'supaul',
  'katiya': 'araria',
  'tikulia': 'supaul',
  'dhengraghat': 'katihar',
  'taibpur': 'katihar',
  'sripalpur': 'patna',
  'sheohar': 'sitamarhi',
  'pandaul': 'madhubani',
};

String _normSite(String v) => v
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _districtFor(RiverStation s) {
  final norm = _normSite(s.city);
  if (_kSiteToDistrict.containsKey(norm)) return _kSiteToDistrict[norm]!;
  for (final entry in _kSiteToDistrict.entries) {
    if (norm.contains(entry.key) || entry.key.contains(norm))
      return entry.value;
  }
  return norm;
}

// ─── Map station list ────────────────────────────────────────────────────────────
//
// autoDispose — only live while BiharRiverMapScreen is mounted.
// Watches only PERSISTENT providers (mapViewModeProvider,
// mergedStationsProvider) so there is no autoDispose→autoDispose chain.
final mapStationsProvider = Provider.autoDispose<List<RiverStation>>((ref) {
  final mode = ref.watch(mapViewModeProvider); // persistent
  final all = ref.watch(mergedStationsProvider); // persistent

  final filtered = mode == MapViewMode.bihar
      ? all.where((s) => s.state.toLowerCase().contains('bihar')).toList()
      : all;

  return List<RiverStation>.from(filtered)
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
});

// ─── District risk map (polygon heatmap layer) ─────────────────────────────────
//
// v1.2: NO LONGER watches mapStationsProvider (autoDispose).
//
// REASON: an autoDispose provider watching another autoDispose provider
// creates a chained subscription that confuses Riverpod 3.x's
// pausedActiveSubscriptionCount bookkeeping on TickerMode changes.
// The fix is to replicate the filter logic here and watch only the two
// PERSISTENT upstream providers (mergedStationsProvider, mapViewModeProvider)
// that mapStationsProvider itself already watches.
//
// Result: mapStationsProvider now has exactly 2 ProviderContainer
// subscriptions while the map screen is open, matching the expected count
// on every _updateTickerMode call.
final biharDistrictRiskProvider =
    Provider.autoDispose<Map<String, DangerClass>>((ref) {
  // Watch persistent providers directly — NOT mapStationsProvider.
  final mode = ref.watch(mapViewModeProvider); // persistent
  final allMerged = ref.watch(mergedStationsProvider); // persistent

  // Apply the same Bihar filter as mapStationsProvider
  final stations = mode == MapViewMode.bihar
      ? allMerged.where((s) => s.state.toLowerCase().contains('bihar')).toList()
      : allMerged;

  final map = <String, DangerClass>{};
  for (final s in stations) {
    if (!s.state.toLowerCase().contains('bihar')) continue;
    final district = _districtFor(s);
    final existing = map[district];
    if (existing == null || s.dangerClass.index > existing.index) {
      map[district] = s.dangerClass;
    }
  }
  return map;
});
