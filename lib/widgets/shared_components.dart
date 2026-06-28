// lib/widgets/shared_components.dart
// OpsFlood — Module 15: Shared Widget Library
//
// Drop-in reusable components used across the app:
//
//  • FloodStatusBadge        — colour-coded severity pill
//  • RiverLevelGauge         — animated vertical fill gauge
//  • AlertCard               — standardised alert list tile
//  • EmptyStateWidget        — icon + message placeholder
//  • LoadingOverlay          — full-screen loading with message
//  • OfflineBanner           — persistent top banner when offline
//  • PulsingDot              — animated live-indicator dot
//  • SectionCard             — white rounded card with header
//  • StatTile                — icon + value + label mini-card
//  • ConfirmDialog           — standardised yes/no dialog
//  • AppSnackBar             — themed SnackBar factory methods

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ============================================================
// FloodStatusBadge
// ============================================================

enum FloodSeverity { normal, watch, warning, danger, emergency }

extension FloodSeverityExt on FloodSeverity {
  String get label => switch (this) {
    FloodSeverity.normal    => 'Normal',
    FloodSeverity.watch     => 'Watch',
    FloodSeverity.warning   => 'Warning',
    FloodSeverity.danger    => 'Danger',
    FloodSeverity.emergency => 'Emergency',
  };
  Color get color => switch (this) {
    FloodSeverity.normal    => const Color(0xFF4CAF50),
    FloodSeverity.watch     => const Color(0xFF8BC34A),
    FloodSeverity.warning   => const Color(0xFFFFEB3B),
    FloodSeverity.danger    => const Color(0xFFFF9800),
    FloodSeverity.emergency => const Color(0xFFEF4444),
  };
  Color get textColor => this == FloodSeverity.warning
      ? const Color(0xFF795548)
      : Colors.white;
}

FloodSeverity severityFromString(String s) => switch (s.toLowerCase()) {
  'normal'    => FloodSeverity.normal,
  'watch'     => FloodSeverity.watch,
  'warning'   => FloodSeverity.warning,
  'danger'    => FloodSeverity.danger,
  'emergency' => FloodSeverity.emergency,
  _           => FloodSeverity.normal,
};

class FloodStatusBadge extends StatelessWidget {
  final FloodSeverity severity;
  final bool small;
  const FloodStatusBadge({
    super.key,
    required this.severity,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 10,
          vertical:   small ? 2 : 4),
      decoration: BoxDecoration(
        color:        severity.color,
        borderRadius: BorderRadius.circular(small ? 4 : 8),
      ),
      child: Text(
        severity.label.toUpperCase(),
        style: TextStyle(
          color:      severity.textColor,
          fontSize:   small ? 9 : 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ============================================================
// RiverLevelGauge
// ============================================================

class RiverLevelGauge extends StatefulWidget {
  /// Current level in metres
  final double current;
  /// Danger level in metres
  final double danger;
  /// Warning level in metres
  final double warning;
  /// Maximum axis value in metres
  final double max;
  final double width;
  final double height;

  const RiverLevelGauge({
    super.key,
    required this.current,
    required this.danger,
    required this.warning,
    required this.max,
    this.width  = 48,
    this.height = 160,
  });

  @override
  State<RiverLevelGauge> createState() =>
      _RiverLevelGaugeState();
}

class _RiverLevelGaugeState extends State<RiverLevelGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>    _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(
      begin: 0,
      end: (widget.current / widget.max).clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _fillColor {
    if (widget.current >= widget.danger)  return const Color(0xFFEF4444);
    if (widget.current >= widget.warning) return const Color(0xFFFF9800);
    return const Color(0xFF42A5F5);
  }

  @override
  Widget build(BuildContext context) {
    final dangerFrac  = (widget.danger  / widget.max).clamp(0.0, 1.0);
    final warningFrac = (widget.warning / widget.max).clamp(0.0, 1.0);
    return SizedBox(
      width:  widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => CustomPaint(
          painter: _GaugePainter(
            fill:        _anim.value,
            color:       _fillColor,
            dangerFrac:  dangerFrac,
            warningFrac: warningFrac,
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fill;
  final Color  color;
  final double dangerFrac;
  final double warningFrac;

  _GaugePainter({
    required this.fill,
    required this.color,
    required this.dangerFrac,
    required this.warningFrac,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(r),
    );
    // Background
    canvas.drawRRect(
        rect, Paint()..color = const Color(0xFFE0E0E0));
    // Fill
    final fillTop = size.height * (1 - fill);
    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, fillTop, size.width,
          size.height - fillTop),
      Radius.circular(r),
    );
    canvas.drawRRect(fillRect, Paint()..color = color);
    // Danger line
    final dy = size.height * (1 - dangerFrac);
    canvas.drawLine(
      Offset(0, dy), Offset(size.width, dy),
      Paint()
        ..color = const Color(0xFFEF4444)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    // Warning line
    final wy = size.height * (1 - warningFrac);
    canvas.drawLine(
      Offset(0, wy), Offset(size.width, wy),
      Paint()
        ..color = const Color(0xFFFF9800)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.fill != fill;
}

// ============================================================
// AlertCard
// ============================================================

class AlertCard extends StatelessWidget {
  final String stationName;
  final String riverName;
  final String district;
  final double currentLevel;
  final double dangerLevel;
  final FloodSeverity severity;
  final DateTime updatedAt;
  final VoidCallback? onTap;

  const AlertCard({
    super.key,
    required this.stationName,
    required this.riverName,
    required this.district,
    required this.currentLevel,
    required this.dangerLevel,
    required this.severity,
    required this.updatedAt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (currentLevel / dangerLevel * 100).clamp(0, 200).toInt();
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Left: severity stripe
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: severity.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Center: text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stationName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        FloodStatusBadge(
                            severity: severity, small: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$riverName • $district',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    // Level progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (currentLevel / dangerLevel)
                            .clamp(0.0, 1.5),
                        backgroundColor: Colors.grey.shade200,
                        color: severity.color,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currentLevel.toStringAsFixed(2)} m  •  $pct% of danger',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EmptyStateWidget
// ============================================================

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String?  subtitle;
  final String?  actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey)),
            if (subtitle != null) ...
              [
                const SizedBox(height: 8),
                Text(subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500)),
              ],
            if (actionLabel != null && onAction != null) ...
              [
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LoadingOverlay
// ============================================================

class LoadingOverlay extends StatelessWidget {
  final String? message;
  const LoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                    color: Color(0xFF0D47A1)),
                if (message != null) ...
                  [
                    const SizedBox(height: 16),
                    Text(message!,
                        style: const TextStyle(
                            fontSize: 13)),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// OfflineBanner
// ============================================================

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF37474F),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.wifi_off,
                  size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Offline — showing cached data',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12),
                ),
              ),
              const PulsingDot(color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PulsingDot
// ============================================================

class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulsingDot({
    super.key,
    this.color = const Color(0xFF4CAF50),
    this.size  = 10,
  });
  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>    _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(
            parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Container(
            width:  widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
}

// ============================================================
// SectionCard
// ============================================================

class SectionCard extends StatelessWidget {
  final String?  title;
  final Widget   child;
  final EdgeInsets padding;
  final Widget?  trailing;

  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0D47A1)),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

// ============================================================
// StatTile
// ============================================================

class StatTile extends StatelessWidget {
  final IconData icon;
  final String   value;
  final String   label;
  final Color    color;

  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey)),
        ],
      ),
    );
  }
}

// ============================================================
// ConfirmDialog
// ============================================================

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel  = 'Cancel',
  bool   destructive  = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
              foregroundColor: destructive
                  ? Colors.red
                  : null),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ============================================================
// AppSnackBar
// ============================================================

class AppSnackBar {
  AppSnackBar._();

  static void success(
    BuildContext context,
    String message, [
    Duration duration = const Duration(seconds: 3),
  ]) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: const Color(0xFF4CAF50),
      duration: duration,
      behavior: SnackBarBehavior.floating,
    ));
  }

  static void error(
    BuildContext context,
    String message, [
    Duration duration = const Duration(seconds: 4),
  ]) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: const Color(0xFFEF4444),
      duration: duration,
      behavior: SnackBarBehavior.floating,
    ));
  }

  static void info(
    BuildContext context,
    String message, [
    Duration duration = const Duration(seconds: 3),
  ]) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF0D47A1),
      duration: duration,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
