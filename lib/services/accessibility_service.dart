// Phase 2 – Accessibility Settings Service
import 'package:dio/dio.dart';
import '../models/accessibility_settings.dart';

class AccessibilityService {
  final Dio _dio;

  AccessibilityService(this._dio);

  Future<AccessibilitySettings> getMySettings() async {
    final resp = await _dio.get('/accessibility/me');
    return AccessibilitySettings.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<AccessibilitySettings> updateSettings(
      AccessibilitySettings settings) async {
    final resp = await _dio.put(
      '/accessibility/me',
      data: settings.toJson()..remove('userId')..remove('user_id'),
    );
    return AccessibilitySettings.fromJson(resp.data as Map<String, dynamic>);
  }

  // Convenience: update single field
  Future<AccessibilitySettings> patchSetting(
      String field, dynamic value) async {
    final resp = await _dio.put(
      '/accessibility/me',
      data: {field: value},
    );
    return AccessibilitySettings.fromJson(resp.data as Map<String, dynamic>);
  }
}
