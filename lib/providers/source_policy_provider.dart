// lib/providers/source_policy_provider.dart  v2.0 (15 Jun 2026)
//
// Fallback source-chain manager.
//
// Chain: WRD Bihar (backend) → Befiqr CWC (live scrape) → Local Seed
// Each hop goes through DataValidator. The first source that passes wins.
// Emits SourcePolicyState — widgets consume dataQualityProvider and
// fallbackBannerProvider without ever knowing which source was used.
//
// v2.0 fixes (15 Jun 2026):
//
//   Fix 1 — DataSource.wrdBihar now actually calls the backend:
//     Previously threw UnimplementedError (TODO left open). Now calls
//     BackendApiService.fetchLiveLevels('Bihar'), converts each Map to a
//     CwcStation-compatible shape, serialises to JSON and passes to
//     DataValidator. The source is treated as failed when the backend
//     returns 0 stations (HTTP 200 + empty list is not useful data).
//
//   Fix 2 — DataSource.localSeed no longer makes a network call:
//     The tertiary was calling BefiqrCwcService().fetchStations() which is
//     identical to the secondary. Both secondary and tertiary therefore
//     failed together whenever Befiqr was down, leaving stations: [].
//     Now uses BefiqrCwcService.seedStations — the static 32-station
//     snapshot that is always available offline, no network required.
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/backend_api_service.dart';
import '../services/befiqr_cwc_service.dart';
import '../services/data_validator.dart';

// ─── Source registry ──────────────────────────────────────────────────────────

enum DataSource {
  wrdBihar, // Primary   — OpsFlood backend (/api/live-levels?state=Bihar)
  befiqrCwc, // Secondary — irrigation.befiqr.in live scrape
  localSeed, // Tertiary  — embedded 32-station snapshot (no network)
}

extension DataSourceLabel on DataSource {
  String get label => switch (this) {
        DataSource.wrdBihar => 'WRD Bihar',
        DataSource.befiqrCwc => 'Befiqr CWC',
        DataSource.localSeed => 'Local Seed',
      };
}

// ─── State ────────────────────────────────────────────────────────────────────

class SourcePolicyState {
  final List<CwcStation> stations;
  final DataQualityState quality;
  final DataSource activeSource;
  final DataSource? failedSource; // null when primary succeeded
  final ValidationFailure? lastFailure; // most recent failure detail
  final bool showFallbackBanner;

  const SourcePolicyState({
    required this.stations,
    required this.quality,
    required this.activeSource,
    this.failedSource,
    this.lastFailure,
    this.showFallbackBanner = false,
  });

  String? get subtleBannerMessage {
    if (!showFallbackBanner) return null;
    if (failedSource == null) return null;
    final fs = failedSource!.label;
    final as_ = activeSource.label;
    return switch (quality) {
      DataQualityState.stale => '$fs data is stale — showing $as_',
      DataQualityState.sourceError => '$fs unavailable — switched to $as_',
      DataQualityState.fresh => 'Using $as_ (primary $fs unavailable)',
    };
  }

  SourcePolicyState copyWith({
    List<CwcStation>? stations,
    DataQualityState? quality,
    DataSource? activeSource,
    DataSource? failedSource,
    ValidationFailure? lastFailure,
    bool? showFallbackBanner,
  }) =>
      SourcePolicyState(
        stations: stations ?? this.stations,
        quality: quality ?? this.quality,
        activeSource: activeSource ?? this.activeSource,
        failedSource: failedSource,
        lastFailure: lastFailure,
        showFallbackBanner: showFallbackBanner ?? this.showFallbackBanner,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SourcePolicyNotifier extends AsyncNotifier<SourcePolicyState> {
  static const _chain = [
    DataSource.wrdBihar,
    DataSource.befiqrCwc,
    DataSource.localSeed,
  ];

  @override
  Future<SourcePolicyState> build() => _fetch();

  /// Pull-to-refresh or timer-triggered re-fetch.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// User dismissed the fallback banner.
  void dismissBanner() {
    state.whenData(
        (s) => state = AsyncData(s.copyWith(showFallbackBanner: false)));
  }

  Future<SourcePolicyState> _fetch() async {
    DataSource? failedSource;
    ValidationFailure? lastFailure;

    for (final source in _chain) {
      try {
        final raw = await _fetchFromSource(source);
        // null means the source deliberately signalled "no usable data".
        if (raw == null) {
          failedSource ??= source;
          continue;
        }

        final result = DataValidator.validateStationListJson(raw);

        if (result.isOk) {
          final stations = result.valueOrNull!;
          final (:valid, :failures) = DataValidator.partitionList(
              stations, DataValidator.validateStation);

          DataQualityState quality = DataQualityState.fresh;
          if (failures.isNotEmpty) {
            final hasStale = failures
                .any((f) => f.kind == ValidationFailureKind.staleTimestamp);
            quality =
                hasStale ? DataQualityState.stale : DataQualityState.fresh;
          }

          return SourcePolicyState(
            stations: valid.isEmpty ? stations : valid,
            quality: quality,
            activeSource: source,
            failedSource: failedSource,
            lastFailure: lastFailure,
            showFallbackBanner: failedSource != null,
          );
        }

        lastFailure = result.failureOrNull;
        failedSource ??= source;
      } catch (_) {
        failedSource ??= source;
      }
    }

    // All sources failed.
    return SourcePolicyState(
      stations: const [],
      quality: DataQualityState.sourceError,
      activeSource: DataSource.localSeed,
      failedSource: failedSource,
      lastFailure: lastFailure,
      showFallbackBanner: true,
    );
  }

  // ─── Per-source fetch helpers ─────────────────────────────────────────────

  Future<String?> _fetchFromSource(DataSource source) async {
    switch (source) {
      // Fix 1: call the real backend instead of throwing UnimplementedError.
      //
      // BackendApiService.fetchLiveLevels returns List<Map<String,dynamic>>
      // whose keys are snake_case (current_level, danger_level, river_name,
      // city …). We normalise each record to the camelCase shape that
      // CwcStation.fromJson / DataValidator expects, then serialise to JSON.
      //
      // Returns null (signals failure) when:
      //   • the HTTP call throws
      //   • the backend returns an empty list (0 stations is not useful)
      case DataSource.wrdBihar:
        final raw = await BackendApiService.instance.fetchLiveLevels('Bihar');
        if (raw.isEmpty) return null; // 0 stations → treat as failed source
        final now = DateTime.now().toIso8601String();
        final normalised = raw.map((m) {
          // Helper: resolve a double from multiple possible key spellings.
          double? d(List<String> keys) {
            for (final k in keys) {
              final v = m[k];
              if (v is num) return v.toDouble();
            }
            return null;
          }

          String s(List<String> keys, String fb) {
            for (final k in keys) {
              final v = m[k];
              if (v is String && v.isNotEmpty) return v;
            }
            return fb;
          }

          return <String, dynamic>{
            'river': s(['river_name', 'river'], ''),
            'site': s(['city', 'station', 'site'], ''),
            'currentLevel': d(['current_level', 'currentLevel']) ?? 0.0,
            'dangerLevel': d(['danger_level', 'dangerLevel']) ?? 0.0,
            'warningLevel': d(['warning_level', 'warningLevel']),
            'trend': m['trend'],
            'status': m['risk_label'] ?? m['status'],
            'source': 'WRD_BIHAR_BACKEND',
            'isFromSeed': false,
            'fetchedAt': m['timestamp'] ?? m['fetchedAt'] ?? now,
          };
        }).toList();
        // Filter out records with dangerLevel == 0 (backend placeholder rows).
        final usable =
            normalised.where((m) => (m['dangerLevel'] as double) > 0).toList();
        if (usable.isEmpty) return null;
        return jsonEncode(usable);

      // Secondary: live scrape from BefiqrCwcService (5-source race).
      case DataSource.befiqrCwc:
        final stations = await BefiqrCwcService().fetchStations();
        if (stations.isEmpty) return null;
        return jsonEncode(stations.map((s) => s.toJson()).toList());

      // Fix 2: tertiary is the embedded static snapshot — zero network calls.
      //
      // BefiqrCwcService.seedStations returns the 32-station June 2026
      // snapshot that is compiled into the app binary. It is always
      // available regardless of connectivity, so localSeed can never
      // throw and always returns a non-null non-empty JSON string.
      case DataSource.localSeed:
        final seed = BefiqrCwcService.seedStations;
        return jsonEncode(seed.map((s) => s.toJson()).toList());
    }
  }
}

final sourcePolicyProvider =
    AsyncNotifierProvider<SourcePolicyNotifier, SourcePolicyState>(
  SourcePolicyNotifier.new,
);

// ─── Derived providers — subscribe to only what you need ─────────────────────

/// Quality state only — widgets that show badges subscribe here.
final dataQualityProvider = Provider<DataQualityState>(
    (ref) => ref.watch(sourcePolicyProvider).maybeWhen(
          data: (s) => s.quality,
          orElse: () => DataQualityState.fresh,
        ));

/// Banner message — null when fresh or user dismissed.
final fallbackBannerProvider =
    Provider<String?>((ref) => ref.watch(sourcePolicyProvider).maybeWhen(
          data: (s) => s.subtleBannerMessage,
          orElse: () => null,
        ));
