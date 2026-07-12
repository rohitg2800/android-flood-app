import 'package:flutter/material.dart';
import '../providers/station_status_provider.dart';
import '../utils/flood_severity.dart';

/// Resolves issue #35: StationStatusBadge — severity color + trend arrow
class StationStatusBadge extends StatelessWidget {
  final FloodSeverityLevel severity;
  final StationTrend trend;
  final bool isOnline;
  final bool compact;

  const StationStatusBadge({
    super.key,
    required this.severity,
    required this.trend,
    this.isOnline = true,
    this.compact = false,
  });

  IconData get _trendIcon {
    if (!isOnline) return Icons.signal_wifi_off;
    switch (trend) {
      case StationTrend.rising:
        return Icons.trending_up;
      case StationTrend.falling:
        return Icons.trending_down;
      case StationTrend.stable:
        return Icons.trending_flat;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Offline stations display as grey/normal — FloodSeverity has no .offline
    final effectiveSeverity = isOnline ? severity : FloodSeverityLevel.normal;
    final baseColor = effectiveSeverity.color;
    // Offline: override to grey regardless of severity
    final color =
        isOnline ? baseColor : const Color(0xFF9A8060); // AppPalette.textGrey

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 8,
            height: compact ? 6 : 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 3 : 5),
          if (!compact) ...[
            Text(
              isOnline ? effectiveSeverity.label : 'Offline',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(_trendIcon, size: compact ? 10 : 13, color: color),
        ],
      ),
    );
  }
}

/// Pulsing animation for new danger alerts (issue #35)
class PulsingStatusBadge extends StatefulWidget {
  final FloodSeverityLevel severity;
  final StationTrend trend;
  final bool isOnline;

  const PulsingStatusBadge({
    super.key,
    required this.severity,
    required this.trend,
    this.isOnline = true,
  });

  @override
  State<PulsingStatusBadge> createState() => _PulsingStatusBadgeState();
}

class _PulsingStatusBadgeState extends State<PulsingStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    final shouldPulse = widget.severity == FloodSeverityLevel.danger ||
        widget.severity == FloodSeverityLevel.extreme;
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (!shouldPulse) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Opacity(
        opacity: _pulse.value,
        child: StationStatusBadge(
          severity: widget.severity,
          trend: widget.trend,
          isOnline: widget.isOnline,
        ),
      ),
    );
  }
}
