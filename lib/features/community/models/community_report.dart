import 'package:freezed_annotation/freezed_annotation.dart';

part 'community_report.freezed.dart';
part 'community_report.g.dart';

enum ReportSeverity { low, medium, high, critical }
enum ReportStatus { pending, verified, dismissed }
enum ReportCategory { flooding, blocked_drain, pump_failure, road_damage, evacuation_needed, other }

@freezed
class CommunityReport with _$CommunityReport {
  const factory CommunityReport({
    required String id,
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    required ReportSeverity severity,
    required ReportStatus status,
    required ReportCategory category,
    required String reportedAt,
    String? reportedBy,
    String? districtName,
    String? imageUrl,
    @Default(0) int upvotes,
  }) = _CommunityReport;

  factory CommunityReport.fromJson(Map<String, dynamic> json) =>
      _$CommunityReportFromJson(json);
}
