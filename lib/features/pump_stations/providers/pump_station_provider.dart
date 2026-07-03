import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/pump_station_repository.dart';

// ── All stations list ──────────────────────────────────────────────────────

class PumpStationFilter {
  final String? district;
  final String? status;
  final String? search;

  const PumpStationFilter({this.district, this.status, this.search});

  @override
  bool operator ==(Object other) =>
      other is PumpStationFilter &&
      other.district == district &&
      other.status == status &&
      other.search == search;

  @override
  int get hashCode => Object.hash(district, status, search);
}

final pumpStationsProvider =
    FutureProvider.family<List<PumpStation>, PumpStationFilter>(
        (ref, filter) async {
  final repo = ref.watch(pumpStationRepositoryProvider);
  return repo.getAllStations(
    district: filter.district,
    status: filter.status,
    search: filter.search,
  );
});

// ── Single station by ID ───────────────────────────────────────────────────

final pumpStationByIdProvider =
    FutureProvider.family<PumpStation, String>((ref, id) async {
  final repo = ref.watch(pumpStationRepositoryProvider);
  return repo.getStationById(id);
});

// ── Station status ─────────────────────────────────────────────────────────

final pumpStationStatusProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.watch(pumpStationRepositoryProvider);
  return repo.getStationStatus(id);
});

// ── Search query state ─────────────────────────────────────────────────────

final pumpStationSearchQueryProvider = StateProvider<String>((ref) => '');

// ── Active status filter ───────────────────────────────────────────────────

final pumpStationStatusFilterProvider = StateProvider<String?>((ref) => null);

// ── Report issue loading state ─────────────────────────────────────────────

class IssueReportNotifier extends StateNotifier<AsyncValue<void>> {
  final PumpStationRepository _repo;
  IssueReportNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<bool> submitReport(IssueReport report) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.reportIssue(report);
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final issueReportProvider =
    StateNotifierProvider<IssueReportNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(pumpStationRepositoryProvider);
  return IssueReportNotifier(repo);
});
