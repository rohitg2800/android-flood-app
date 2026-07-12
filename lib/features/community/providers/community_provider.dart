import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/features/community/models/community_report.dart';

class CommunityRepository {
  const CommunityRepository();

  Future<List<CommunityReport>> fetchReports() async {
    return const [];
  }

  Future<void> submitReport({
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    required ReportSeverity severity,
    required ReportCategory category,
  }) async {}

  Future<void> upvoteReport(String reportId) async {}
}

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return const CommunityRepository();
});

final communityReportsProvider =
    FutureProvider<List<CommunityReport>>((ref) async {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.fetchReports();
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
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(communityRepositoryProvider);
    state = await AsyncValue.guard(() => repo.submitReport(
          title: title,
          description: description,
          latitude: latitude,
          longitude: longitude,
          severity: severity,
          category: category,
        ));
  }
}

final submitReportProvider =
    AsyncNotifierProvider<SubmitReportNotifier, void>(SubmitReportNotifier.new);
