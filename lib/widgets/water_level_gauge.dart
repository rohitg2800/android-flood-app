// lib/widgets/water_level_gauge.dart
// Closes #45 — Animated water level gauge widget
import 'package:flutter/material.dart';
import '../services/water_level_service.dart';

/// Animated water-level fill gauge with colour-coded status chip.
///
/// Drop into any screen:
/// ```dart
/// WaterLevelGauge(service: _waterLevelService)
/// ```
class WaterLevelGauge extends StatelessWidget {
  final WaterLevelService service;

  /// Max gauge scale in metres (full bar = this value).
  final double maxLevelMeters;

  const WaterLevelGauge({
    super.key,
    required this.service,
    this.maxLevelMeters = 10.0,
  });

  Color _statusColor(WaterStatus s) => switch (s) {
        WaterStatus.normal => const Color(0xFF22C55E),   // green-500
        WaterStatus.warning => const Color(0xFFF59E0B),  // amber-500
        WaterStatus.danger => const Color(0xFFEF4444),   // red-500
        WaterStatus.critical => const Color(0xFFDC2626), // red-600
      };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WaterLevelReading>(
      stream: service.stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const _GaugeSkeleton();
        }
        final reading = snap.data!;
        final fill =
            (reading.levelMeters / maxLevelMeters).clamp(0.0, 1.0);
        final color = _statusColor(reading.status);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Station name + status chip
            Row(
              children: [
                Expanded(
                  child: Text(
                    reading.stationName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: reading.status, color: color),
              ],
            ),
            const SizedBox(height: 10),

            // Animated fill bar
            LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  // Track
                  Container(
                    height: 14,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  // Fill
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeInOut,
                    height: 14,
                    width: constraints.maxWidth * fill,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Level value + last-updated
            Row(
              children: [
                Text(
                  '${reading.levelMeters.toStringAsFixed(2)} m',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                ),
                const Spacer(),
                Text(
                  'Updated ${_ago(reading.recordedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

/// Shimmer-style skeleton shown before the first reading arrives.
class _GaugeSkeleton extends StatefulWidget {
  const _GaugeSkeleton();

  @override
  State<_GaugeSkeleton> createState() => _GaugeSkeletonState();
}

class _GaugeSkeletonState extends State<_GaugeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 14,
            width: 140,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(_anim.value),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(_anim.value * 0.5),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact status badge chip.
class _StatusChip extends StatelessWidget {
  final WaterStatus status;
  final Color color;

  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
