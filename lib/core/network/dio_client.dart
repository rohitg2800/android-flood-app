import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _baseUrl =
    'https://android-flood-app-production.up.railway.app';

Dio createDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Add auth token here if needed
        handler.next(options);
      },
      onError: (DioException e, handler) {
        // Centralised error handling
        handler.next(e);
      },
    ),
  );

  return dio;
}

final dioClientProvider = Provider<Dio>((ref) => createDio());
