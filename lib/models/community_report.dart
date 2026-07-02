import 'package:freezed_annotation/freezed_annotation.dart';

part 'community_report.freezed.dart';
part 'community_report.g.dart';

@freezed
class CommunityReport with _$CommunityReport {
  const factory CommunityReport({
    required String id,
    required String title,
    required String description,
    required String reportType,
    required double latitude,
    required double longitude,
    required String status,
    required String submittedBy,
    required DateTime submittedAt,
    String? imageUrl,
    String? address,
    @Default(0) int upvotes,
  }) = _CommunityReport;

  factory CommunityReport.fromJson(Map<String, dynamic> json) =>
      _$CommunityReportFromJson(json);
}
