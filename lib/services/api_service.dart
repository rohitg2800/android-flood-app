// lib/services/api_service.dart
// Legacy health-check wrapper — kept for backwards compatibility.
// Delegates to BackendApiService.checkHealth() which routes through OpsClient.
import 'backend_api_service.dart';

class ApiService {
  Future<bool> checkHealth() async {
    try {
      final result = await BackendApiService.instance.checkHealth();
      return result['status'] == 'ok' || result.containsKey('status');
    } catch (_) {
      return false;
    }
  }
}
