// lib/services/ws_gauge_service.dart  Step 2.2
// WebSocket singleton — connects to /ws/gauges, auto-reconnects with
// exponential backoff, falls back to HTTP polling if WS stays down > 30s.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../models/flood_data.dart';
import '../config/env_config.dart';

enum WsStatus { connecting, connected, fallback, offline }

class WsGaugeService {
  WsGaugeService._();
  static final WsGaugeService instance = WsGaugeService._();

  // ── Public streams ────────────────────────────────────────────────────────
  final _dataController   = StreamController<List<FloodData>>.broadcast();
  final _statusController = StreamController<WsStatus>.broadcast();

  Stream<List<FloodData>> get stream       => _dataController.stream;
  Stream<WsStatus>        get statusStream => _statusController.stream;

  WsStatus _status = WsStatus.offline;
  WsStatus get currentStatus => _status;

  // ── Internal state ────────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _fallbackTimer;
  Timer? _pingTimer;
  int  _retryCount  = 0;
  bool _disposed    = false;
  DateTime? _lastDataAt;

  static const _maxRetry     = 6;       // 3→6→12→24→48→60s then cap
  static const _pingInterval = Duration(seconds: 20);
  static const _fallbackDelay = Duration(seconds: 30);
  static const _fallbackPoll  = Duration(seconds: 60);

  String get _wsUrl {
    final base = EnvConfig.backendBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://',  'ws://');
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
    _sub?.cancel();
    _reconnectTimer?.cancel();
    _fallbackTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _dataController.close();
    _statusController.close();
  }

  // ── WebSocket connect ─────────────────────────────────────────────────────
  void _connect() {
    if (_disposed) return;
    _setStatus(WsStatus.connecting);
    _cancelFallback();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
    } catch (e) {
      debugPrint('[WS] connect error: $e');
      _scheduleReconnect();
      _scheduleFallback();
      return;
    }

    _sub?.cancel();
    _sub = _channel!.stream.listen(
      _onMessage,
      onError: (e) {
        debugPrint('[WS] stream error: $e');
        _scheduleReconnect();
        _scheduleFallback();
      },
      onDone: () {
        debugPrint('[WS] connection closed');
        _scheduleReconnect();
        _scheduleFallback();
      },
    );

    _startPing();

    // If no message arrives in 30s, activate HTTP fallback
    _scheduleFallback();
  }

  void _onMessage(dynamic raw) {
    _retryCount = 0;
    _cancelFallback();
    _setStatus(WsStatus.connected);
    _lastDataAt = DateTime.now();

    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      List<dynamic> list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map && decoded.containsKey('data')) {
        list = decoded['data'] as List<dynamic>;
      } else {
        return;
      }
      final gauges = list
          .map((e) => FloodData.fromJson(e as Map<String, dynamic>))
          .toList();
      _dataController.add(gauges);
    } catch (e) {
      debugPrint('[WS] parse error: $e');
    }
  }

  // ── Reconnect backoff ─────────────────────────────────────────────────────
  void _scheduleReconnect() {
    if (_disposed) return;
    _sub?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();

    final delay = Duration(seconds: _backoffSeconds());
    debugPrint('[WS] reconnecting in ${delay.inSeconds}s (attempt $_retryCount)');
    _retryCount = (_retryCount + 1).clamp(0, _maxRetry);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  int _backoffSeconds() {
    const caps = [3, 6, 12, 24, 48, 60];
    return caps[_retryCount.clamp(0, caps.length - 1)];
  }

  // ── HTTP fallback ─────────────────────────────────────────────────────────
  void _scheduleFallback() {
    if (_disposed) return;
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(_fallbackDelay, _startHttpFallback);
  }

  void _cancelFallback() {
    _fallbackTimer?.cancel();
  }

  Timer? _httpPollTimer;

  void _startHttpFallback() {
    if (_disposed || _status == WsStatus.connected) return;
    _setStatus(WsStatus.fallback);
    debugPrint('[WS] activating HTTP fallback poll');
    _httpPoll();
    _httpPollTimer?.cancel();
    _httpPollTimer = Timer.periodic(_fallbackPoll, (_) => _httpPoll());
  }

  Future<void> _httpPoll() async {
    if (_disposed) return;
    try {
      final resp = await http
          .get(Uri.parse(_httpUrl))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        List<dynamic> list;
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          list = decoded['data'] as List<dynamic>;
        } else {
          return;
        }
        final gauges = list
            .map((e) => FloodData.fromJson(e as Map<String, dynamic>))
            .toList();
        _lastDataAt = DateTime.now();
        _dataController.add(gauges);
        if (_status == WsStatus.offline) _setStatus(WsStatus.fallback);
      }
    } catch (e) {
      debugPrint('[WS] HTTP poll error: $e');
      _setStatus(WsStatus.offline);
    }
  }

  // ── Ping ──────────────────────────────────────────────────────────────────
  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      try {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {}
    });
  }

  // ── Status ────────────────────────────────────────────────────────────────
  void _setStatus(WsStatus s) {
    if (_status == s) return;
    _status = s;
    _statusController.add(s);
  }

  DateTime? get lastDataAt => _lastDataAt;
}
