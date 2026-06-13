// lib/services/bihar_live_engine.dart  v3.1.1
//
// v3.1.1: Fix LiveRiverResult field access in _liveResultToItem.
//         All other logic identical to v3.1.
//
// v3.1: Registry-locked DL/WL/HFL for all Bihar gauge items
//       + staleness-gated severity recompute for all 193 stations.
//
// Changes vs v3.0:
//   - _gaugeFromRegistry()  fuzzy-matches kBiharGauges by station name.
//   - _registryThresholds() returns canonical WL/DL/HFL (or zeros if unknown).
//   - _dangerToSeverityFromLevels() recomputes severity via gaugeRiskFromLevels()
//     instead of trusting the external source's label string.
//   - _staleness guard: items with fetchedAt > _maxItemAge (3 h) are clamped
//     to NewsSeverity.info — fixes "alerts from old data".
//   - _wrdStationToItem, _biharStationToItem, _kosiReadingToItem, and the
//     CWC block in _fetchIndiaStations all overlay registry thresholds.
//   - _liveResultToItem: fields accessed via r.station.* (RiverStation);
//     fetchedAt parsed from r.station.lastUpdated ISO string.
//   - _floodDataToItem retains source thresholds but gains staleness guard.
//
// Slot priority (unchanged): rt > rtdas > wrd > wrd_scrape > kosi > wris
//   > india > news
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/bihar_rivers.dart';
import '../models/flood_data.dart';
import 'befiqr_cwc_service.dart';
import 'bihar_wrd_scraper.dart';
import 'india_stations_service.dart';
import 'kosi_birpur_service.dart';
import 'news_service.dart';
import 'real_time_river_service.dart';
import 'rtdas_threshold_sync_service.dart';
import 'threshold_override_store.dart';
import 'wrd_bihar_service.dart';
import 'wris_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Domain models (unchanged from v3.0)
// ─────────────────────────────────────────────────────────────────────────────

enum FeedItemKind { riverGauge, news, alert, barrage, telemetry }

enum SourceId {
  wrdBihar,
  cwcBefiqr,
  kosiBirpur,
  wris,
  realTimeRiver,
  indiaStations,
  news,
  rtdas,
}

class SourceHealth {
  final SourceId id;
  final bool ok;
  final String? error;
  final DateTime lastAttempt;
  final Duration? latency;

  const SourceHealth({
    required this.id,
    required this.ok,
    this.error,
    required this.lastAttempt,
    this.latency,
  });

  SourceHealth copyWith({bool? ok, String? error, Duration? latency}) =>
      SourceHealth(
        id:          id,
        ok:          ok          ?? this.ok,
        error:       error       ?? this.error,
        lastAttempt: lastAttempt,
        latency:     latency     ?? this.latency,
      );

  @override
  String toString() =>
      'SourceHealth($id ok=$ok latency=${latency?.inMilliseconds}ms'
      '${error != null ? ' err=$error' : ''})';
}

class BiharFeedItem {
  final String       id;
  final FeedItemKind kind;
  final SourceId     source;
  final String       title;
  final String       subtitle;
  final String?      value;
  final String?      dangerLevel;
  final String?      changeStr;
  final String?      url;
  final DateTime     fetchedAt;
  final NewsSeverity severity;
  final Map<String, dynamic> raw;

  const BiharFeedItem({
    required this.id,
    required this.kind,
    required this.source,
    required this.title,
    required this.subtitle,
    this.value,
    this.dangerLevel,
    this.changeStr,
    this.url,
    required this.fetchedAt,
    this.severity = NewsSeverity.info,
    this.raw = const {},
  });
}

class BiharLiveFeed {
  final List<BiharFeedItem>          items;
  final Map<SourceId, SourceHealth>  health;
  final DateTime                     generatedAt;
  final bool                         isPartial;

  const BiharLiveFeed({
    required this.items,
    required this.health,
    required this.generatedAt,
    this.isPartial = false,
  });

  List<BiharFeedItem> get sorted {
    final copy = [...items];
    copy.sort((a, b) {
      final sc = b.severity.index.compareTo(a.severity.index);
      return sc != 0 ? sc : b.fetchedAt.compareTo(a.fetchedAt);
    });
    return copy;
  }

  List<BiharFeedItem> byKind(FeedItemKind k) =>
      items.where((i) => i.kind == k).toList();

  int get errorCount => health.values.where((h) => !h.ok).length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Engine v3.1.1
// ─────────────────────────────────────────────────────────────────────────────

class BiharLiveEngine {
  BiharLiveEngine._();
  static final BiharLiveEngine instance = BiharLiveEngine._();

  static const _gaugeInterval = Duration(minutes: 15);
  static const _newsInterval  = Duration(minutes: 10);
  static const _kosiInterval  = Duration(minutes: 20);
  static const _rtdasInterval = Duration(hours: 6);
  static const _timeout       = Duration(seconds: 20);

  // v3.1: items older than this are clamped to severity=info regardless of
  //       water level — prevents stale cache entries from showing as alerts.
  static const _maxItemAge = Duration(hours: 3);

  final _wrd         = WrdBiharService.instance;
  final _befiqr      = BefiqrCwcService();
  final _kosiBirpur  = KosiBirpurService();
  final _wris        = WrisService.instance;
  final _rtRiver     = RealTimeRiverService();
  final _indStations = IndiaStationsService();
  final _wrdScraper  = BiharWrdScraper.instance;
  final _news        = NewsService();

  final _controller = StreamController<BiharLiveFeed>.broadcast();
  BiharLiveFeed?    _latest;
  Timer?            _gaugeTimer;
  Timer?            _newsTimer;
  Timer?            _kosiTimer;
  Timer?            _rtdasTimer;
  bool              _running = false;

  // ── v3.1: pre-built fuzzy lookup index over kBiharGauges ─────────────────
  Map<String, BiharGauge>? _registryIndex;

  Map<String, BiharGauge> get _registry {
    if (_registryIndex != null) return _registryIndex!;
    final idx = <String, BiharGauge>{};
    for (final g in kBiharGauges) {
      for (final key in _gaugeKeys(g.station)) {
        idx.putIfAbsent(key, () => g);
      }
    }
    _registryIndex = idx;
    return idx;
  }

  static List<String> _gaugeKeys(String name) {
    final base = name.toLowerCase().trim();
    final keys = <String>{base};
    final paren = base.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    if (paren.isNotEmpty) keys.add(paren);
    final dash = base.split(' - ').first.trim();
    if (dash.isNotEmpty) keys.add(dash);
    for (final sfx in [' barrage', ' bridge', ' (cwc)', ' (wrd)', ' ghat']) {
      if (base.endsWith(sfx)) keys.add(base.substring(0, base.length - sfx.length).trim());
    }
    return keys.toList();
  }

  BiharGauge? _gaugeFromRegistry(String stationName) {
    for (final key in _gaugeKeys(stationName)) {
      final g = _registry[key];
      if (g != null) return g;
    }
    return null;
  }

  ({double wl, double dl, double hfl}) _registryThresholds(
    String stationName, {
    double fallbackWl = 0,
    double fallbackDl = 0,
    double fallbackHfl = 0,
  }) {
    final g = _gaugeFromRegistry(stationName);
    return g != null
        ? (wl: g.warningLevel, dl: g.dangerLevel, hfl: g.hfl)
        : (wl: fallbackWl,     dl: fallbackDl,    hfl: fallbackHfl);
  }

  // ── Named slots ────────────────────────────────────────────────────────────
  final Map<String, List<BiharFeedItem>> _slots = {
    'rt':         [],
    'rtdas':      [],
    'wrd':        [],
    'wrd_scrape': [],
    'kosi':       [],
    'wris':       [],
    'india':      [],
    'news':       [],
  };

  final Map<SourceId, SourceHealth> _health = {};

  Stream<BiharLiveFeed> get stream  => _controller.stream;
  BiharLiveFeed?        get latest  => _latest;
  bool                  get running => _running;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    debugPrint('[BiharLiveEngine] starting v3.1.1 …');

    unawaited(RtdasThresholdSyncService.instance.start());

    await refresh();
    _gaugeTimer = Timer.periodic(_gaugeInterval, (_) => _fetchGauge());
    _newsTimer  = Timer.periodic(_newsInterval,  (_) => _fetchNews());
    _kosiTimer  = Timer.periodic(_kosiInterval,  (_) => _fetchKosi());
    _rtdasTimer = Timer.periodic(_rtdasInterval, (_) => _fetchRtdasThresholds());
  }

  void stop() {
    _gaugeTimer?.cancel();
    _newsTimer?.cancel();
    _kosiTimer?.cancel();
    _rtdasTimer?.cancel();
    _running = false;
    debugPrint('[BiharLiveEngine] stopped.');
  }

  Future<void> refresh() async {
    debugPrint('[BiharLiveEngine] full refresh …');
    await Future.wait([
      _fetchGauge(),
      _fetchNews(),
      _fetchKosi(),
      _fetchWris(),
      _fetchRealTime(),
      _fetchIndiaStations(),
      _fetchRtdasThresholds(),
    ]);
    _emit();
  }

  // ── slot write helper ──────────────────────────────────────────────────────

  void _setSlot(String key, List<BiharFeedItem> items) {
    _slots[key] = items;
    _emit();
  }

  // ── fetch workers ──────────────────────────────────────────────────────────

  Future<void> _fetchGauge() async {
    final t0 = DateTime.now();
    try {
      final data = await _wrd.fetch().timeout(_timeout);
      _slots['wrd'] = data.map(_wrdStationToItem).toList();
      _setHealth(SourceId.wrdBihar, true, DateTime.now().difference(t0));

      try {
        final scraped = await _wrdScraper.fetchAll().timeout(_timeout);
        final wrdIds  = { for (final i in _slots['wrd']!) i.id };
        _slots['wrd_scrape'] =
            scraped.map(_biharStationToItem)
                   .where((i) => !wrdIds.contains(i.id))
                   .toList();
      } catch (_) {}
    } catch (e) {
      _setHealth(SourceId.wrdBihar, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] WRD: $e');
    }
    _emit();
  }

  Future<void> _fetchKosi() async {
    final t0 = DateTime.now();
    try {
      final data = await _kosiBirpur.fetchLive().timeout(_timeout);
      _setSlot('kosi', [_kosiReadingToItem(data)]);
      _setHealth(SourceId.kosiBirpur, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.kosiBirpur, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] Kosi: $e');
      _emit();
    }
  }

  Future<void> _fetchWris() async {
    final t0 = DateTime.now();
    try {
      final data = await _wris.fetchBiharTelemetry().timeout(_timeout);
      _setSlot('wris', _listToItems(
        data, SourceId.wris, FeedItemKind.telemetry,
        titleKey: 'stationName', valueKey: 'waterLevel',
        dangerKey: 'alertLevel', subtitleKey: 'riverName',
      ));
      _setHealth(SourceId.wris, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.wris, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] WRIS: $e');
      _emit();
    }
  }

  Future<void> _fetchRealTime() async {
    final t0 = DateTime.now();
    try {
      final results = await _rtRiver.fetchAll().timeout(_timeout);
      _setSlot('rt', results.map(_liveResultToItem).toList());
      _setHealth(SourceId.realTimeRiver, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.realTimeRiver, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] RT-River: $e');
      _emit();
    }
  }

  Future<void> _fetchIndiaStations() async {
    final t0 = DateTime.now();
    try {
      final stations = await _indStations.fetchAll().timeout(_timeout);

      List<BiharFeedItem> befiqrItems = [];
      try {
        final cwcStations = await _befiqr.fetchStations().timeout(_timeout);
        befiqrItems = cwcStations.map((s) {
          final th = _registryThresholds(
            s.site,
            fallbackWl:  s.warningLevel ?? (s.dangerLevel - 1),
            fallbackDl:  s.dangerLevel,
            fallbackHfl: s.dangerLevel + 2,
          );
          final fetchedAt  = s.fetchedAt;
          final sev        = _severityGated(
            _dangerToSeverityFromLevels(s.currentLevel, th.wl, th.dl, th.hfl),
            fetchedAt,
          );
          final statusLabel = _riskLabelFromLevels(s.currentLevel, th.wl, th.dl, th.hfl);
          return BiharFeedItem(
            id:          'cwc|${s.site.toLowerCase().trim()}',
            kind:        FeedItemKind.riverGauge,
            source:      SourceId.cwcBefiqr,
            title:       s.site,
            subtitle:    'River: ${s.river}',
            value:       '${s.currentLevel.toStringAsFixed(2)} m',
            dangerLevel: statusLabel,
            fetchedAt:   fetchedAt ?? DateTime.now(),
            severity:    sev,
            raw: {
              'river':   s.river,
              'site':    s.site,
              'level':   s.currentLevel,
              'danger':  th.dl,
              'warning': th.wl,
              'hfl':     th.hfl,
            },
          );
        }).toList();
        _setHealth(SourceId.cwcBefiqr, true, DateTime.now().difference(t0));
      } catch (_) {}

      _setSlot('india', [...stations.map(_floodDataToItem), ...befiqrItems]);
      _setHealth(SourceId.indiaStations, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.indiaStations, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] IndiaStations: $e');
      _emit();
    }
  }

  Future<void> _fetchNews() async {
    final t0 = DateTime.now();
    try {
      final items = await _news.fetchAll();
      _setSlot('news', items.map(_newsToItem).toList());
      _setHealth(SourceId.news, true, DateTime.now().difference(t0));
    } catch (e) {
      _setHealth(SourceId.news, false, DateTime.now().difference(t0), '$e');
      debugPrint('[BiharLiveEngine] News: $e');
      _emit();
    }
  }

  // ── RTDAS slot (unchanged from v3.0) ─────────────────────────────────────
  Future<void> _fetchRtdasThresholds() async {
    final store = ThresholdOverrideStore.instance;
    final now   = DateTime.now();
    final items = <BiharFeedItem>[];

    if (store.isStale('__last_full_sync__', maxHours: 18)) {
      unawaited(RtdasThresholdSyncService.instance.forceSync());
    }

    items.add(BiharFeedItem(
      id:        'rtdas|__sync_marker__',
      kind:      FeedItemKind.telemetry,
      source:    SourceId.rtdas,
      title:     'RTDAS Threshold Sync',
      subtitle:  'WRD Bihar / BEAMS — ${store.count} stations cached',
      value:     'age: ${store.ageHours('__last_full_sync__')?.toStringAsFixed(1) ?? '?'}h',
      fetchedAt: now,
      raw: {'stationCount': store.count},
    ));

    _setSlot('rtdas', items);
    _setHealth(SourceId.rtdas, true, Duration.zero);
    debugPrint('[BiharLiveEngine] rtdas slot refreshed — ${store.count} thresholds in store');
  }

  // ── emit ───────────────────────────────────────────────────────────────────
  void _emit() {
    final seen  = <String>{};
    final dedup = <BiharFeedItem>[];

    for (final key in
        ['rt', 'rtdas', 'wrd', 'wrd_scrape', 'kosi', 'wris', 'india', 'news']) {
      for (final item in (_slots[key] ?? [])) {
        if (seen.add(item.id)) dedup.add(item);
      }
    }

    final feed = BiharLiveFeed(
      items:       dedup,
      health:      Map.unmodifiable(_health),
      generatedAt: DateTime.now(),
      isPartial:   _health.values.any((h) => !h.ok),
    );
    _latest = feed;
    if (!_controller.isClosed) _controller.add(feed);
    debugPrint('[BiharLiveEngine] emitted ${dedup.length} items '
        '(${feed.errorCount} source errors)');
  }

  // ── health ─────────────────────────────────────────────────────────────────

  void _setHealth(SourceId id, bool ok, Duration latency, [String? err]) {
    _health[id] = SourceHealth(
      id: id, ok: ok, error: err,
      lastAttempt: DateTime.now(), latency: latency,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // v3.1 — severity helpers
  // ─────────────────────────────────────────────────────────────────────────

  NewsSeverity _dangerToSeverityFromLevels(
      double current, double wl, double dl, double hfl) {
    final risk = gaugeRiskFromLevels(
      current: current, warning: wl, danger: dl, hfl: hfl,
    );
    switch (risk) {
      case 'EXTREME':  return NewsSeverity.critical;
      case 'CRITICAL': return NewsSeverity.critical;
      case 'DANGER':   return NewsSeverity.high;
      default:         return NewsSeverity.info;
    }
  }

  String _riskLabelFromLevels(
      double current, double wl, double dl, double hfl) {
    final risk = gaugeRiskFromLevels(
      current: current, warning: wl, danger: dl, hfl: hfl,
    );
    switch (risk) {
      case 'EXTREME':  return 'Extreme';
      case 'CRITICAL': return 'Danger';
      case 'DANGER':   return 'Warning';
      default:         return 'Normal';
    }
  }

  NewsSeverity _severityGated(NewsSeverity computed, DateTime fetchedAt) {
    if (DateTime.now().difference(fetchedAt) > _maxItemAge) {
      return NewsSeverity.info;
    }
    return computed;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // v3.1.1 — item converters
  // ─────────────────────────────────────────────────────────────────────────

  BiharFeedItem _wrdStationToItem(WrdStation s) {
    final level = s.currentLevel?.toStringAsFixed(2) ?? '—';
    final cur   = s.currentLevel ?? 0.0;
    final th    = _registryThresholds(
      s.site,
      fallbackDl:  s.dangerLevel ?? 0,
      fallbackWl:  (s.dangerLevel != null) ? s.dangerLevel! - 1.0 : 0,
      fallbackHfl: (s.dangerLevel != null) ? s.dangerLevel! + 2.0 : 0,
    );
    final fetchedAt = s.fetchedAt;
    final sev    = _severityGated(
      _dangerToSeverityFromLevels(cur, th.wl, th.dl, th.hfl), fetchedAt);
    final status = _riskLabelFromLevels(cur, th.wl, th.dl, th.hfl);
    return BiharFeedItem(
      id:          'wrd|${s.site.toLowerCase().trim()}',
      kind:        FeedItemKind.riverGauge,
      source:      SourceId.wrdBihar,
      title:       s.site,
      subtitle:    s.river.isNotEmpty ? 'River: ${s.river}' : 'WRD Bihar',
      value:       '$level m',
      dangerLevel: status,
      fetchedAt:   fetchedAt ?? DateTime.now(),
      severity:    sev,
      raw: {
        'river':   s.river,  'site':    s.site,
        'level':   cur,      'danger':  th.dl,
        'warning': th.wl,    'hfl':     th.hfl,
      },
    );
  }

  BiharFeedItem _biharStationToItem(BiharStationReading r) {
    final level = r.currentLevel.toStringAsFixed(2);
    final cur   = r.currentLevel;
    final th    = _registryThresholds(
      r.stationName,
      fallbackDl:  r.dangerLevel ?? 0,
      fallbackWl:  (r.dangerLevel != null) ? r.dangerLevel! - 1.0 : 0,
      fallbackHfl: r.hfl ?? ((r.dangerLevel != null) ? r.dangerLevel! + 2.0 : 0),
    );
    final change = r.diff != null
        ? '${r.diff! >= 0 ? '+' : ''}${r.diff!.toStringAsFixed(2)} m '
          '${r.trend == 'Rising' ? '↑' : r.trend == 'Falling' ? '↓' : '→'}'
        : null;
    final fetchedAt = r.observedAt;
    final sev    = _severityGated(
      _dangerToSeverityFromLevels(cur, th.wl, th.dl, th.hfl), fetchedAt);
    final status = _riskLabelFromLevels(cur, th.wl, th.dl, th.hfl);
    return BiharFeedItem(
      id:          'wrd_scrape|${r.stationName.toLowerCase().trim()}',
      kind:        FeedItemKind.riverGauge,
      source:      SourceId.wrdBihar,
      title:       r.stationName,
      subtitle:    r.river.isNotEmpty ? 'River: ${r.river}' : 'WRD Scrape',
      value:       '$level m',
      dangerLevel: status,
      changeStr:   change,
      fetchedAt:   fetchedAt ?? DateTime.now(),
      severity:    sev,
      raw: {
        'river':    r.river,    'station': r.stationName,
        'district': r.district, 'level':   cur,
        'danger':   th.dl,      'warning': th.wl,
        'hfl':      th.hfl,     'trend':   r.trend,
        'status':   status,
      },
    );
  }

  BiharFeedItem _floodDataToItem(FloodData fd) {
    final level     = fd.currentLevel.toStringAsFixed(2);
    final status    = fd.riskLevel;
    final fetchedAt = fd.lastUpdated;
    final sev       = _severityGated(_riskToSeverity(status), fetchedAt ?? DateTime.now());
    return BiharFeedItem(
      id:          'india|${fd.city.toLowerCase().trim()}',
      kind:        FeedItemKind.riverGauge,
      source:      SourceId.indiaStations,
      title:       fd.city,
      subtitle:    fd.riverName != null && fd.riverName!.isNotEmpty
                       ? 'River: ${fd.riverName}'
                       : fd.state,
      value:       '$level m',
      dangerLevel: status,
      fetchedAt:   fetchedAt ?? DateTime.now(),
      severity:    sev,
      raw: {
        'city':    fd.city,        'state':   fd.state,
        'river':   fd.riverName,   'level':   fd.currentLevel,
        'danger':  fd.dangerLevel, 'warning': fd.warningLevel,
        'risk':    fd.riskLevel,
      },
    );
  }

  BiharFeedItem _kosiReadingToItem(KosiBirpurReading r) {
    final th = _registryThresholds(
      'Birpur (CWC)',
      fallbackDl:  r.dangerLevel,
      fallbackWl:  r.warningLevel,
      fallbackHfl: r.dangerLevel + 1.5,
    );
    final fetchedAt = r.observedAt;
    final sev    = _severityGated(
      _dangerToSeverityFromLevels(r.levelM, th.wl, th.dl, th.hfl), fetchedAt);
    final status = _riskLabelFromLevels(r.levelM, th.wl, th.dl, th.hfl);
    return BiharFeedItem(
      id:          'kosi|birpur',
      kind:        FeedItemKind.barrage,
      source:      SourceId.kosiBirpur,
      title:       'Birpur',
      subtitle:    'Kosi Barrage',
      value:       '${r.levelM.toStringAsFixed(2)} m',
      dangerLevel: status,
      fetchedAt:   fetchedAt ?? DateTime.now(),
      severity:    sev,
      raw: {
        'river':   'Kosi',   'station': 'Birpur',
        'level':   r.levelM, 'danger':  th.dl,
        'warning': th.wl,    'hfl':     th.hfl,
      },
    );
  }

  // v3.1.1: LiveRiverResult wraps a RiverStation — all fields accessed via
  // r.station.*  (stationName→station.station, levelM→station.current, etc.)
  // fetchedAt parsed from station.lastUpdated ISO string; falls back to now.
  // r.isStale additionally clamps severity to info.
  BiharFeedItem _liveResultToItem(LiveRiverResult r) {
    final st        = r.station;
    final fetchedAt = st.lastUpdated != null
        ? (DateTime.tryParse(st.lastUpdated!) ?? DateTime.now())
        : DateTime.now();
    // Stale if either the isStale flag is set OR the timestamp is too old
    final isStale   = r.isStale ||
        DateTime.now().difference(fetchedAt) > _maxItemAge;
    final baseSev   = _dangerToSeverityFromLevels(
        st.current, st.warning, st.danger, st.hfl);
    final sev       = isStale ? NewsSeverity.info : baseSev;
    final status    = _riskLabelFromLevels(st.current, st.warning, st.danger, st.hfl);
    return BiharFeedItem(
      id:          'rt|${st.station.toLowerCase().trim()}',
      kind:        FeedItemKind.riverGauge,
      source:      SourceId.realTimeRiver,
      title:       st.station,
      subtitle:    st.river.isNotEmpty ? 'River: ${st.river}' : 'RT River',
      value:       '${st.current.toStringAsFixed(2)} m',
      dangerLevel: status,
      fetchedAt:   fetchedAt ?? DateTime.now(),
      severity:    sev,
      raw: {
        'river':   st.river,    'station': st.station,
        'city':    st.city,     'state':   st.state,
        'level':   st.current,  'danger':  st.danger,
        'warning': st.warning,  'hfl':     st.hfl,
        'source':  r.source,    'stale':   r.isStale,
      },
    );
  }

  BiharFeedItem _newsToItem(NewsItem n) => BiharFeedItem(
    id:        'news|${n.url ?? n.title}',
    kind:      FeedItemKind.news,
    source:    SourceId.news,
    title:     n.title,
    subtitle:  n.source ?? '',
    url:       n.url,
    fetchedAt: n.publishedAt ?? DateTime.now(),
    severity:  n.severity,
    raw: {'url': n.url, 'source': n.source},
  );

  // ── legacy string-label helpers ────────────────────────────────────────────

  NewsSeverity _dangerToSeverity(String? label) {
    switch ((label ?? '').toLowerCase()) {
      case 'extreme': return NewsSeverity.critical;
      case 'danger':  return NewsSeverity.critical;
      case 'warning': return NewsSeverity.high;
      default:        return NewsSeverity.info;
    }
  }

  NewsSeverity _riskToSeverity(String? risk) {
    switch ((risk ?? '').toLowerCase()) {
      case 'extreme':  return NewsSeverity.critical;
      case 'critical': return NewsSeverity.critical;
      case 'high':     return NewsSeverity.high;
      case 'moderate': return NewsSeverity.high;
      default:         return NewsSeverity.info;
    }
  }

  // ── generic list→items (WRIS telemetry) ────────────────────────────────────
  List<BiharFeedItem> _listToItems(
    List<Map<String, dynamic>> data,
    SourceId source,
    FeedItemKind kind, {
    required String titleKey,
    required String valueKey,
    required String dangerKey,
    required String subtitleKey,
  }) {
    return data.map((m) {
      final title     = m[titleKey]?.toString() ?? '';
      final val       = m[valueKey]?.toString() ?? '—';
      final danger    = m[dangerKey]?.toString() ?? '';
      final subtitle  = m[subtitleKey]?.toString() ?? '';
      final fetchedAt = m['fetchedAt'] is DateTime
          ? m['fetchedAt'] as DateTime
          : DateTime.now();
      final sev = _severityGated(_dangerToSeverity(danger), fetchedAt);
      return BiharFeedItem(
        id:          '${source.name}|${title.toLowerCase().trim()}',
        kind:        kind,
        source:      source,
        title:       title,
        subtitle:    subtitle,
        value:       val,
        dangerLevel: danger,
        fetchedAt:   fetchedAt ?? DateTime.now(),
        severity:    sev,
        raw:         m,
      );
    }).toList();
  }
}