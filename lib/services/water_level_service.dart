// lib/services/water_level_service.dart
// Closes #45 — Flutter WebSocket client with exponential backoff
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Status levels mapped from water level thresholds (in metres).
enum WaterStatus { normal, warning, danger, critical }

extension WaterStatusLabel on WaterStatus {
  String get label => name.toUpperCase();
}

/// A single water-level reading received from the WebSocket feed.
class WaterLevelReading {
  final String id;
  final String stationName;
  final String? zoneId;
  final double levelMeters;
  final String source;
  final DateTime recordedAt;

  const WaterLevelReading({
    required this.id,
    required this.stationName,
    this.zoneId,
    required this.levelMeters,
    required this.source,
    required this.recordedAt,
  });

  factory WaterLevelReading.fromJson(Map<String, dynamic> j) =>
      WaterLevelReading(
        id: j['id']?.toString() ?? '',
        stationName: j['station_name'] as String? ?? '',
        zoneId: j['zone_id'] as String?,
        levelMeters: (j['level_meters'] as num).toDouble(),
        source: j['source'] as String? ?? 'manual',
        recordedAt: DateTime.parse(j['recorded_at'] as String),
      );

  /// Threshold-based status (thresholds in metres — adjust to your gauges).
  WaterStatus get status {
    if (levelMeters >= 8.0) return WaterStatus.critical;
    if (levelMeters >= 6.0) return WaterStatus.danger;
    if (levelMeters >= 4.0) return WaterStatus.warning;
    return WaterStatus.normal;
  }
}

/// Service that maintains a WebSocket connection to the backend
/// `/ws/water-levels` endpoint and exposes a broadcast [Stream].
///
/// Usage:
/// ```dart
/// final svc = WaterLevelService(stationName: 'Patna_Ganga');
/// svc.connect();
/// // then in a StreamBuilder: stream: svc.stream
/// svc.dispose(); // in State.dispose()
/// ```
class WaterLevelService {
  // TODO: move to env / config
  static const String _baseWsUrl =
      'wss://your-backend.railway.app/ws/water-levels';

  final String stationName;

  WebSocketChannel? _channel;
  final _controller = StreamController<WaterLevelReading>.broadcast();
  Timer? _reconnectTimer;
  int _retryDelaySec = 1; // starts at 1s, doubles up to 30s
  bool _disposed = false;

  WaterLevelService({this.stationName = '*'});

  /// Broadcast stream of [WaterLevelReading] — subscribe in a StreamBuilder.
  Stream<WaterLevelReading> get stream => _controller.stream;

  /// Open the WebSocket connection (also called automatically on reconnect).
  void connect() {
    if (_disposed) return;
    final uri =
        Uri.parse('$_baseWsUrl?station_name=${Uri.encodeComponent(stationName)}');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      _onMessage,
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
      cancelOnError: false,
    );
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    _retryDelaySec = 1; // reset backoff on successful message
    final data = jsonDecode(raw as String) as Map<String, dynamic>;

    if (data['type'] == 'history') {
      // Initial batch of last-20 readings
      final list = data['data'] as List<dynamic>;
      for (final item in list) {
        _emit(item as Map<String, dynamic>);
      }
    } else {
      // Live delta update
      _emit(data);
    }
  }

  void _emit(Map<String, dynamic> json) {
    try {
      _controller.add(WaterLevelReading.fromJson(json));
    } catch (_) {
      // Malformed message — skip silently
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _retryDelaySec), () {
      _retryDelaySec = (_retryDelaySec * 2).clamp(1, 30);
      connect();
    });
  }

  /// Release all resources. Call from [State.dispose].
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
