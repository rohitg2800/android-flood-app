/// WaterLevelService — WebSocket client for real-time water level feed.
/// Issue #45
///
/// Usage:
///   final service = WaterLevelService(stationName: 'Bagmati-1');
///   service.stream.listen((reading) { ... });
///   service.dispose();

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../models/water_level_reading.dart';

enum WsConnectionStatus { connecting, connected, reconnecting, disconnected }

class WaterLevelService {
  final String baseWsUrl;
  final String? stationName;

  WaterLevelService({
    required this.baseWsUrl,
    this.stationName,
  });

  // Public streams
  final _readingController = StreamController<WaterLevelReading>.broadcast();
  final _statusController =
      StreamController<WsConnectionStatus>.broadcast();

  Stream<WaterLevelReading> get stream => _readingController.stream;
  Stream<WsConnectionStatus> get statusStream => _statusController.stream;

  WsConnectionStatus _status = WsConnectionStatus.disconnected;
  WsConnectionStatus get status => _status;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _disposed = false;
  int _retryCount = 0;
  static const int _maxRetries = 10;

  /// Connect and start streaming.
  Future<void> connect() async {
    if (_disposed) return;
    _setStatus(WsConnectionStatus.connecting);
    try {
      final uri = _buildUri();
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _setStatus(WsConnectionStatus.connected);
      _retryCount = 0;

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final map = json.decode(raw as String) as Map<String, dynamic>;
      final type = map['type'] as String?;
      if (type == 'ping') return; // heartbeat — ignore
      final reading = WaterLevelReading.fromJson(map);
      _readingController.add(reading);
    } catch (_) {}
  }

  void _onError(Object error) => _scheduleReconnect();

  void _onDone() {
    if (!_disposed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _retryCount >= _maxRetries) {
      _setStatus(WsConnectionStatus.disconnected);
      return;
    }
    _setStatus(WsConnectionStatus.reconnecting);
    // Exponential backoff: 1s, 2s, 4s … capped at 30s
    final delay = Duration(
      milliseconds:
          min(30000, (1000 * pow(2, _retryCount)).toInt()),
    );
    _retryCount++;
    Future.delayed(delay, connect);
  }

  void _setStatus(WsConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }

  Uri _buildUri() {
    final base = baseWsUrl.replaceFirst(RegExp(r'/$'), '');
    final query =
        stationName != null ? '?station_id=${Uri.encodeComponent(stationName!)}' : '';
    return Uri.parse('$base/ws/water-levels$query');
  }

  /// Disconnect and clean up.
  Future<void> dispose() async {
    _disposed = true;
    await _sub?.cancel();
    await _channel?.sink.close(ws_status.goingAway);
    await _readingController.close();
    await _statusController.close();
  }
}
