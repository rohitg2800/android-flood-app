import 'package:dio/dio.dart';

export 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;
  ApiClient(String baseUrl)
      : _dio = Dio(BaseOptions(baseUrl: baseUrl));
  Dio get dio => _dio;
}
