import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../models/db/water_level_reading.dart';
import 'auth_service.dart';

class WaterLevelWebSocketService {
  WaterLevelWebSocketService({
    required AuthService authService,
    required String wsBaseUrl,
  })  : _authService = authService,
        _wsBaseUrl = wsBaseUrl;

  final AuthService _authService;
  final String _wsBaseUrl;

  WebSocketChannel? _channel;
  StreamController<List<WaterLevelReading>>? _controller;
  Timer? _reconnectTimer;
  bool _manuallyClosed = false;

  Stream<List<WaterLevelReading>> connect({
    String? state,
    String? district,
    List<String>? stationCodes,
  }) {
    _manuallyClosed = false;

    _controller ??= StreamController<List<WaterLevelReading>>.broadcast(
      onListen: () {
        _openSocket(
          state: state,
          district: district,
          stationCodes: stationCodes,
        );
      },
      onCancel: () async {
        await disconnect();
      },
    );

    return _controller!.stream;
  }

  Future<void> _openSocket({
    String? state,
    String? district,
    List<String>? stationCodes,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      _controller?.addError('Missing auth token for live water level feed.');
      return;
    }

    final uri = _buildUri(
      state: state,
      district: district,
      stationCodes: stationCodes,
      token: token,
    );

    _channel?.sink.close(status.goingAway);
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (message) {
        try {
          final readings = _parseMessage(message);
          _controller?.add(readings);
        } catch (e, st) {
          _controller?.addError(e, st);
        }
      },
      onError: (error, stackTrace) {
        if (!_manuallyClosed) {
          _controller?.addError(error, stackTrace);
          _scheduleReconnect(
            state: state,
            district: district,
            stationCodes: stationCodes,
          );
        }
      },
      onDone: () {
        if (!_manuallyClosed) {
          _scheduleReconnect(
            state: state,
            district: district,
            stationCodes: stationCodes,
          );
        }
      },
      cancelOnError: false,
    );
  }

  Uri _buildUri({
    String? state,
    String? district,
    List<String>? stationCodes,
    required String token,
  }) {
    final query = <String, dynamic>{
      'token': token,
    };

    if (state != null && state.isNotEmpty) {
      query['state'] = state;
    }
    if (district != null && district.isNotEmpty) {
      query['district'] = district;
    }
    if (stationCodes != null && stationCodes.isNotEmpty) {
      query['stations'] = stationCodes.join(',');
    }

    return Uri.parse(_wsBaseUrl).replace(
      queryParameters: query.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  List<WaterLevelReading> _parseMessage(dynamic rawMessage) {
    if (rawMessage is String) {
      final decoded = jsonDecode(rawMessage) as Map<String, dynamic>;
      final type = decoded['type'] as String?;
      final data = decoded['data'];

      if (data == null) return const [];

      if (type == 'snapshot' && data is List) {
        return data
            .cast<Map<String, dynamic>>()
            .map(WaterLevelReading.fromJson)
            .toList();
      }

      if (type == 'reading' && data is Map<String, dynamic>) {
        return [WaterLevelReading.fromJson(data)];
      }

      // Fallback: treat as array of readings.
      if (data is List) {
        return data
            .cast<Map<String, dynamic>>()
            .map(WaterLevelReading.fromJson)
            .toList();
      }
      if (decoded.containsKey('station_name')) {
        return [WaterLevelReading.fromJson(decoded)];
      }
    }

    return const [];
  }

  void _scheduleReconnect({
    String? state,
    String? district,
    List<String>? stationCodes,
  }) {
    _reconnectTimer?.cancel();
    if (_manuallyClosed) return;

    // Simple fixed delay; you can replace with backoff later.
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _openSocket(
        state: state,
        district: district,
        stationCodes: stationCodes,
      );
    });
  }

  Future<void> disconnect() async {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _channel?.sink.close(status.normalClosure);
    _channel = null;

    await _controller?.close();
    _controller = null;
  }

  bool get isConnected => _channel != null;
}
