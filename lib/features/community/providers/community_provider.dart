import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/features/community/models/community_report.dart';
import 'package:equinox_flood/features/community/repositories/community_repository.dart';

final communityReportsProvider =
    FutureProvider<List<CommunityReport>>((ref) async {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.fetchReports();
});

final filteredReportsProvider =
    FutureProvider.family<List<CommunityReport>, ReportStatus>(
        (ref, status) async {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.fetchReports(status: status);
});

class SubmitReportNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    required ReportSeverity severity,
    required ReportCategory category,
    String? imageUrl,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(communityRepositoryProvider);
      await repo.submitReport(
        title: title,
        description: description,
        latitude: latitude,
        longitude: longitude,
        severity: severity,
        category: category,
        imageUrl: imageUrl,
      );
      ref.invalidate(communityReportsProvider);
    });
  }
}

final submitReportProvider =
    AsyncNotifierProvider<SubmitReportNotifier, void>(SubmitReportNotifier.new);
