import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_endpoints.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint(obj.toString()),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (DioException e, ErrorInterceptorHandler handler) {
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.receiveTimeout:
          case DioExceptionType.sendTimeout:
            throw TimeoutException('Request timed out. Please try again.');
          case DioExceptionType.badResponse:
            final statusCode = e.response?.statusCode;
            final message = e.response?.data?['detail'] ?? 'Server error';
            throw ApiException(statusCode: statusCode, message: message);
          case DioExceptionType.connectionError:
            throw NetworkException('No internet connection.');
          default:
            throw ApiException(message: e.message ?? 'Unknown error');
        }
      },
    ),
  );

  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio);
});

class ApiClient {
  final Dio _dio;
  ApiClient(this._dio);

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get(path, queryParameters: queryParameters);
    return response.data;
  }

  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
    );
    return response.data;
  }

  Future<dynamic> put(
    String path, {
    dynamic data,
  }) async {
    final response = await _dio.put(path, data: data);
    return response.data;
  }

  Future<dynamic> patch(
    String path, {
    dynamic data,
  }) async {
    final response = await _dio.patch(path, data: data);
    return response.data;
  }

  Future<dynamic> delete(String path) async {
    final response = await _dio.delete(path);
    return response.data;
  }
}

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException({this.statusCode, required this.message});

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}

void debugPrint(String message) {
  // ignore: avoid_print
  print('[ApiClient] $message');
}
