import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/db/water_level_reading.dart';
import '../services/auth_service.dart';
import '../services/water_level_websocket_service.dart';

final waterLevelWebSocketServiceProvider =
    Provider<WaterLevelWebSocketService>((ref) {
  const wsBaseUrl =
      'wss://android-flood-app-production.up.railway.app/ws/water-levels';

  return WaterLevelWebSocketService(
    authService: AuthService(),
    wsBaseUrl: wsBaseUrl,
  );
});

final waterLevelStreamProvider =
    StreamProvider.autoDispose<List<WaterLevelReading>>((ref) {
  final service = ref.watch(waterLevelWebSocketServiceProvider);

  ref.onDispose(() {
    service.disconnect();
  });

  return service.connect();
});

final waterLevelByStateProvider = StreamProvider.family
    .autoDispose<List<WaterLevelReading>, String>((ref, state) {
  final service = ref.watch(waterLevelWebSocketServiceProvider);

  ref.onDispose(() {
    service.disconnect();
  });

  return service.connect(state: state);
});
