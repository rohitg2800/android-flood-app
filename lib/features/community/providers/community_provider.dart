import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommunityReport {
  final String id;
  final String title;
  final String description;
  final int upvotes;

  const CommunityReport({
    required this.id,
    required this.title,
    required this.description,
    this.upvotes = 0,
  });

  CommunityReport copyWith({
    String? id,
    String? title,
    String? description,
    int? upvotes,
  }) {
    return CommunityReport(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      upvotes: upvotes ?? this.upvotes,
    );
  }
}

class CommunityRepository {
  const CommunityRepository();

  Future<List<CommunityReport>> fetchReports() async {
    return const [];
  }

  Future<void> submitReport(CommunityReport report) async {}

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

final submitReportProvider = Provider<Future<void> Function(CommunityReport)>(
  (ref) {
    final repo = ref.watch(communityRepositoryProvider);
    return (CommunityReport report) => repo.submitReport(report);
  },
);
