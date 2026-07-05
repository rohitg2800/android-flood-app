/// WaterLevelGauge — animated fill bar with color-coded status.
/// Issue #45
///
/// Usage:
///   WaterLevelGauge(
///     service: WaterLevelService(baseWsUrl: Env.wsUrl, stationName: 'X'),
///   )

import 'package:flutter/material.dart';

import '../models/water_level_reading.dart';
import '../services/water_level_service.dart';

class WaterLevelGauge extends StatefulWidget {
  final WaterLevelService service;
  final double maxLevelMeters;

  const WaterLevelGauge({
    super.key,
    required this.service,
    this.maxLevelMeters = 10.0,
  });

  @override
  State<WaterLevelGauge> createState() => _WaterLevelGaugeState();
}

class _WaterLevelGaugeState extends State<WaterLevelGauge>
    with SingleTickerProviderStateMixin {
  WaterLevelReading? _latest;
  WsConnectionStatus _connStatus = WsConnectionStatus.connecting;
  late AnimationController _flashCtrl;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    widget.service.connect();

    widget.service.stream.listen((r) {
      if (mounted) setState(() => _latest = r);
    });
    widget.service.statusStream.listen((s) {
      if (mounted) setState(() => _connStatus = s);
    });
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    widget.service.dispose();
    super.dispose();
  }

  Color _statusColor(WaterLevelStatus s) {
    switch (s) {
      case WaterLevelStatus.normal:
        return const Color(0xFF4CAF50); // green
      case WaterLevelStatus.warning:
        return const Color(0xFFFF9800); // amber
      case WaterLevelStatus.danger:
        return const Color(0xFFF44336); // red
      case WaterLevelStatus.critical:
        return const Color(0xFFB71C1C); // deep red (flashes)
    }
  }

  String _connLabel(WsConnectionStatus s) {
    switch (s) {
      case WsConnectionStatus.connected:
        return '● Live';
      case WsConnectionStatus.connecting:
        return '◌ Connecting…';
      case WsConnectionStatus.reconnecting:
        return '↻ Reconnecting…';
      case WsConnectionStatus.disconnected:
        return '✕ Disconnected';
    }
  }

  Color _connColor(WsConnectionStatus s) {
    switch (s) {
      case WsConnectionStatus.connected:
        return const Color(0xFF4CAF50);
      case WsConnectionStatus.connecting:
      case WsConnectionStatus.reconnecting:
        return const Color(0xFFFF9800);
      case WsConnectionStatus.disconnected:
        return const Color(0xFFF44336);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reading = _latest;
    final fill = reading != null
        ? (reading.levelMeters / widget.maxLevelMeters).clamp(0.0, 1.0)
        : 0.0;
    final status =
        reading?.status ?? WaterLevelStatus.normal;
    final color = _statusColor(status);
    final isCritical = status == WaterLevelStatus.critical;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Station + connection status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  reading?.stationName ?? widget.service.stationName ?? 'All Stations',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  _connLabel(_connStatus),
                  style: TextStyle(
                    color: _connColor(_connStatus),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Animated fill bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AnimatedBuilder(
                animation: _flashCtrl,
                builder: (ctx, _) {
                  final displayColor = isCritical
                      ? Color.lerp(
                          color, Colors.orange, _flashCtrl.value)!
                      : color;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fill),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    builder: (ctx, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 28,
                      backgroundColor: Colors.grey.shade200,
                      color: displayColor,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Level + status badge + timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  reading != null
                      ? '${reading.levelMeters.toStringAsFixed(2)} m'
                      : '— m',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            if (reading != null) ...
              [
                const SizedBox(height: 6),
                Text(
                  'Updated: ${_formatTime(reading.recordedAt)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
                if (reading.flowRate != null)
                  Text(
                    'Flow rate: ${reading.flowRate!.toStringAsFixed(1)} m³/s',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
              ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }
}
