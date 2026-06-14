// lib/providers/map_command_provider.dart  v1.1
//
// v1.1 (14 Jun 2026) — Fix Riverpod 3.x pausedActiveSubscriptionCount crash
//
//   CRASH:
//     Expected pausedActiveSubscriptionCount to be 4, but was 5.
//     ProviderElement<List<RiverStation>>#34699 (origin: mapStationsProvider)
//
//   ROOT CAUSE:
//     mapStationsProvider and biharDistrictRiskProvider were plain (non-autoDispose)
//     Providers that are ONLY ever watched from the BiharRiverMapScreen widget subtree.
//     In Riverpod 3.x, when a persistent Provider is watched exclusively from a widget
//     that unmounts, the subscription is closed (listenerCount drops to 0) without
//     going through the pause path.  However the element itself remains alive and its
//     own upstream subscriptions (to mapViewModeProvider + mergedStationsProvider) are
//     still registered.  When TickerMode then fires ConsumerStatefulElement._updateTickerMode
//     it tries to resume those subscriptions, but biharDistrictRiskProvider's
//     subscription to mapStationsProvider was never paused → count mismatch assertion.
//
//   FIX:
//     Convert both providers to Provider.autoDispose.  An autoDispose provider is
//     fully torn down (all upstream subscriptions cancelled) the moment its last
//     listener disappears — no lingering element, no count mismatch.
//     The map screen is a ConsumerWidget / ConsumerStatefulWidget so the providers
//     are recreated on re-entry at negligible cost (pure synchronous computation).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/cwc_provider.dart';
import '../services/befiqr_cwc_service.dart';

export 'cwc_provider.dart' show biharGeoJsonProvider;

// ─── View-mode toggle ─────────────────────────────────────────────────────────
enum MapViewMode { bihar, national }

class MapViewModeNotifier extends Notifier<MapViewMode> {
  @override
  MapViewMode build() => MapViewMode.bihar;
}

final mapViewModeProvider =
    NotifierProvider<MapViewModeNotifier, MapViewMode>(
        MapViewModeNotifier.new);

// ─── Selected station (popup) ─────────────────────────────────────────────────
class SelectedStationNotifier extends Notifier<RiverStation?> {
  @override
  RiverStation? build() => null;
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
      if (cwcUpdated    != null) cwcUpdated!,
      if (wrdUpdated    != null) wrdUpdated!,
      if (gloFasUpdated != null) gloFasUpdated!,
    ];
    if (times.isEmpty) return 'No data yet';
    times.sort();
    final diff = DateTime.now().difference(times.last);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes} min ago';
    if (diff.inHours   < 24)  return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  String labelFor(String source) {
    switch (source) {
      case 'CWC_FFEM':  return cwcUpdated    == null ? '—' : _fmt(cwcUpdated!);
      case 'WRD_BIHAR': return wrdUpdated    == null ? '—' : _fmt(wrdUpdated!);
      case 'GLOFAS':    return gloFasUpdated == null ? '—' : _fmt(gloFasUpdated!);
      default: return '—';
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

// ─── CwcStation → RiverStation adapter ───────────────────────────────────────
extension CwcStationAdapter on CwcStation {
  RiverStation toRiverStation() => RiverStation(
    city:    site,
    state:   'Bihar',
    river:   river,
    station: site,
    current: currentLevel,
    warning: (dangerLevel - 1.5).clamp(0, double.infinity),
    danger:  dangerLevel,
    hfl:     dangerLevel + 1.5,
    dataSource:  'CWC_FFEM',
    lastUpdated: '${fetchedAt.hour.toString().padLeft(2, '0')}:'
                 '${fetchedAt.minute.toString().padLeft(2, '0')}',
    isLive:  true,
  );
}

// ─── Gauge-site → Bihar district lookup ──────────────────────────────────────
const Map<String, String> _kSiteToDistrict = {
  'ekmighat': 'darbhanga', 'kamtaul': 'darbhanga', 'sonbarsa': 'sitamarhi',
  'benibad': 'darbhanga', 'dheng bridge': 'muzaffarpur', 'dhengbridge': 'muzaffarpur',
  'hayaghat': 'darbhanga', 'runnisaidpur': 'sitamarhi', 'pupri': 'sitamarhi',
  'lalbakeya': 'sitamarhi', 'donar': 'sitamarhi',
  'khagaria': 'khagaria', 'rosera': 'samastipur', 'samastipur': 'samastipur',
  'sikandarpur': 'muzaffarpur', 'gaighat': 'muzaffarpur',
  'chatia': 'east champaran', 'dumariaghat': 'west champaran', 'hajipur': 'vaishali',
  'rewaghat': 'saran', 'balmikinagar': 'west champaran', 'balmiki nagar': 'west champaran',
  'turkaulia': 'west champaran', 'sikta': 'west champaran', 'bhitaha': 'west champaran',
  'bagaha': 'west champaran', 'lauriya': 'west champaran', 'motihari': 'east champaran',
  'areraj': 'east champaran',
  'bhagalpur': 'bhagalpur', 'buxar': 'buxar', 'dighaghat': 'patna',
  'gandhighat': 'patna', 'hathidah': 'begusarai', 'kahalgaon': 'bhagalpur',
  'munger': 'munger', 'naugachia': 'bhagalpur',
  'darauli': 'saran', 'gangpur siswan': 'siwan', 'gangpur': 'siwan',
  'jhanjharpur': 'madhubani',
  'jainagar': 'madhubani', 'phulparas': 'madhubani', 'nirmali': 'supaul',
  'baltara': 'khagaria', 'basua': 'supaul', 'birpur': 'supaul',
  'kursela': 'katihar', 'bhim nagar': 'supaul', 'bhimnagar': 'supaul',
  'katiya': 'araria', 'tikulia': 'supaul',
  'dhengraghat': 'katihar', 'taibpur': 'katihar',
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
    if (norm.contains(entry.key) || entry.key.contains(norm)) return entry.value;
  }
  return norm;
}

// ─── Map station list ─────────────────────────────────────────────────────────
//
// v1.1: Provider.autoDispose — MUST be autoDispose.
//   This provider watches mapViewModeProvider (a persistent NotifierProvider)
//   AND mergedStationsProvider (a persistent Provider).  It is only ever
//   watched from the BiharRiverMapScreen widget subtree.  When the map screen
//   is popped, the widget unmounts and its subscription closes.  If the
//   provider were persistent, Riverpod 3.x would keep the ProviderElement
//   alive with dead upstream subscriptions, and a subsequent TickerMode change
//   would fire _updateTickerMode → resume() on a subscription that was never
//   paused → pausedActiveSubscriptionCount assertion crash.
//
//   autoDispose tears down the ProviderElement (and all its upstream subs)
//   as soon as the last listener disappears — no lingering state, no crash.
final mapStationsProvider = Provider.autoDispose<List<RiverStation>>((ref) {
  final mode = ref.watch(mapViewModeProvider);
  final all  = ref.watch(mergedStationsProvider);

  final filtered = mode == MapViewMode.bihar
      ? all.where((s) => s.state.toLowerCase().contains('bihar')).toList()
      : all;

  return List<RiverStation>.from(filtered)
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
});

// ─── District risk map (polygon heatmap layer) ────────────────────────────────
//
// v1.1: Provider.autoDispose — same reasoning as mapStationsProvider above.
//   This provider only lives while the map screen is visible.
final biharDistrictRiskProvider = Provider.autoDispose<Map<String, DangerClass>>((ref) {
  final stations = ref.watch(mapStationsProvider);
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
