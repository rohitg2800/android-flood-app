import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/features/community/models/community_report.dart';
import 'package:equinox_flood/core/network/dio_client.dart';

class CommunityRepository {
  final Dio _dio;

  CommunityRepository(this._dio);

  Future<List<CommunityReport>> fetchReports({
    ReportStatus? status,
    ReportSeverity? severity,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status.name;
    if (severity != null) queryParams['severity'] = severity.name;
    final response =
        await _dio.get('/api/community-reports', queryParameters: queryParams);
    final List data = response.data as List;
    return data
        .map((e) => CommunityReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CommunityReport> submitReport({
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    required ReportSeverity severity,
    required ReportCategory category,
    String? imageUrl,
  }) async {
    final response = await _dio.post('/api/community-reports', data: {
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'severity': severity.name,
      'category': category.name,
      if (imageUrl != null) 'image_url': imageUrl,
    });
    return CommunityReport.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> upvoteReport(String id) async {
    await _dio.post('/api/community-reports/$id/upvote');
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return CommunityRepository(dio);
});
