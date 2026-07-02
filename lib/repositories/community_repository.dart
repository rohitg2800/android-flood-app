import 'package:dio/dio.dart';
import '../models/community_report.dart';

class CommunityRepository {
  final Dio _dio;
  CommunityRepository(this._dio);

  Future<List<CommunityReport>> getReports() async {
    final response = await _dio.get('/api/community/reports');
    return (response.data as List)
        .map((e) => CommunityReport.fromJson(e))
        .toList();
  }

  Future<CommunityReport> submitReport(CommunityReport report) async {
    final response = await _dio.post(
      '/api/community/reports',
      data: report.toJson(),
    );
    return CommunityReport.fromJson(response.data);
  }

  Future<void> upvoteReport(String id) async {
    await _dio.post('/api/community/reports/$id/upvote');
  }
}
