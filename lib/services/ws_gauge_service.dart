// lib/services/ws_gauge_service.dart  v1.0 — Step 2.2
// Singleton WebSocket service that maintains a live connection to the
// backend /ws/gauges endpoint and exposes a Stream<List<FloodData>>.
// Falls back to HTTP polling when WS is unavailable.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../models/flood_data.dart';
import '../config/env_config.dart';

enum WsStatus { connecting, connected, polling, offline }

class WsGaugeService {
  WsGaugeService._();
  static final WsGaugeService instance = WsGaugeService._();

  // ── Public streams ────────────────────────────────────────────────────────
  final _dataCtrl    = StreamController<List<FloodData>>.broadcast();
  final _statusCtrl  = StreamController<WsStatus>.broadcast();
  final _syncCtrl    = StreamController<DateTime>.broadcast();

  Stream<List<FloodData>> get stream => _dataCtrl.stream;
  Stream<WsStatus>        get status => _statusCtrl.stream;
  Stream<DateTime>        get lastSync => _syncCtrl.stream;

  // ── Internal state ────────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  Timer?            _reconnectTimer;
  Timer?            _pingTimer;
  Timer?            _fallbackTimer;
  Timer?            _pollTimer;
  int               _retryCount = 0;
  bool              _disposed   = false;
  WsStatus          _currentStatus = WsStatus.connecting;

  static const int    _maxRetry       = 6;      // max backoff steps
  static const int    _fallbackSec    = 30;     // WS timeout before HTTP fallback
  static const int    _pollIntervalSec = 45;    // HTTP polling interval
  static const int    _pingIntervalSec = 20;    // WS keepalive ping

  String get _wsUrl {
    final base = EnvConfig.backendBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$base/ws/gauges';
  }

  String get _httpUrl => '${EnvConfig.backendBaseUrl}/api/live-levels';

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  void start() {
    if (_disposed) return;
    _connect();
  }

  void dispose() {
    _disposed = true;
    _cancelTimers();
    _channel?.sink.close();
    _dataCtrl.close();
    _statusCtrl.close();
    _syncCtrl.close();
  }

  // ── WebSocket connection ──────────────────────────────────────────────────
  void _connect() {
    if (_disposed) return;
    _emit(WsStatus.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _startFallbackTimer();

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone:  _onDone,
        cancelOnError: false,
      );

      _startPing();
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    _cancelFallbackTimer();
    _cancelPollTimer();
    _retryCount = 0;

    if (_currentStatus != WsStatus.connected) {
      _emit(WsStatus.connected);
    }

    try {
      final decoded = jsonDecode(raw as String);
      // Backend sends either a list directly or { "data": [...] }
      final List<dynamic> list = decoded is List
          ? decoded
          : (decoded['data'] as List<dynamic>? ?? []);

      final gauges = list
          .map((j) => FloodData.fromJson(j as Map<String, dynamic>))
          .toList();

      if (gauges.isNotEmpty) {
        _dataCtrl.add(gauges);
        _syncCtrl.add(DateTime.now());
      }
    } catch (_) {
      // Malformed frame — keep connection alive, skip frame
    }
  }

  void _onError(dynamic err) {
    _emit(WsStatus.offline);
    _scheduleReconnect();
  }

  void _onDone() {
    if (_currentStatus == WsStatus.connected) {
      _scheduleReconnect();
    }
  }

  // ── Ping keepalive ────────────────────────────────────────────────────────
  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      const Duration(seconds: _pingIntervalSec),
      (_) {
        try {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      },
    );
  }

  // ── Fallback: switch to HTTP polling if WS doesn't connect within 30s ─────
  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(
      const Duration(seconds: _fallbackSec),
      _startHttpPolling,
    );
  }

  void _cancelFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  void _startHttpPolling() {
    if (_disposed) return;
    _emit(WsStatus.polling);
    _fetchHttp(); // immediate first poll
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: _pollIntervalSec),
      (_) => _fetchHttp(),
    );
  }

  void _cancelPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetchHttp() async {
    if (_disposed) return;
    try {
      final resp = await http
          .get(Uri.parse(_httpUrl))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final List<dynamic> list = decoded is List
            ? decoded
            : (decoded['data'] as List<dynamic>? ?? []);
        final gauges = list
            .map((j) => FloodData.fromJson(j as Map<String, dynamic>))
            .toList();
        if (gauges.isNotEmpty) {
          _dataCtrl.add(gauges);
          _syncCtrl.add(DateTime.now());
        }
        if (_currentStatus != WsStatus.connected) {
          _emit(WsStatus.polling);
        }
      }
    } catch (_) {
      _emit(WsStatus.offline);
    }
  }

  // ── Exponential backoff reconnect ─────────────────────────────────────────
  void _scheduleReconnect() {
    if (_disposed) return;
    _cancelTimers();
    final delay = math.min(
      3 * math.pow(2, _retryCount).toInt(),
      60,
    );
    _retryCount = math.min(_retryCount + 1, _maxRetry);
    _reconnectTimer = Timer(Duration(seconds: delay), _connect);
  }

  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _fallbackTimer?.cancel();
    // NOTE: poll timer intentionally NOT cancelled here —
    // it survives reconnect attempts so data keeps flowing during WS outage.
  }

  void _emit(WsStatus s) {
    _currentStatus = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  /// Force a manual HTTP refresh (called by user tapping Offline banner).
  Future<void> forceRefresh() => _fetchHttp();
}

// ── Riverpod provider exposed for convenience ──────────────────────────────
final wsGaugeServiceProvider = Provider<WsGaugeService>((ref) {
  final svc = WsGaugeService.instance;
  svc.start();
  ref.onDispose(svc.dispose);
  return svc;
});
