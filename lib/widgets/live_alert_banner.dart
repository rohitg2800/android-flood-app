// lib/widgets/live_alert_banner.dart  v2.0
//
// v2.0 changes:
//   - Added AlertSeverity.extreme tier (above HFL) with red-violet glow
//   - Added rate-of-rise chip below subMessage
//   - Added LIVE/ESTIMATED source badge
//   - Auto-dismiss now respects severity:
//       extreme/critical → never auto-dismiss
//       danger           → 120 s
//       rising/warning   → 60 s
//   - Removed: autoDismissSeconds constructor param (now derived from severity)
//   - Added: AlertSeverityBannerList — consumes ActiveAlertController.stream
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/active_alert_controller.dart';
import '../theme/river_theme.dart';

// ── Severity → visual mapping ──────────────────────────────────────────────────
extension _AlertVisuals on AlertSeverity {
  Color color(BuildContext ctx) => switch (this) {
        AlertSeverity.extreme => const Color(0xFFD32F2F), // deep red
        AlertSeverity.critical => AppPalette.critical,
        AlertSeverity.danger => AppPalette.warning,
        AlertSeverity.rising => const Color(0xFF039BE5), // sky blue
        AlertSeverity.normal => AppPalette.textGrey,
      };

  Color glowColor(BuildContext ctx) => switch (this) {
        AlertSeverity.extreme =>
          const Color(0xFFD32F2F).withValues(alpha: 0.35),
        AlertSeverity.critical => AppPalette.critical.withValues(alpha: 0.28),
        AlertSeverity.danger => AppPalette.warning.withValues(alpha: 0.22),
        AlertSeverity.rising => const Color(0xFF039BE5).withValues(alpha: 0.20),
        AlertSeverity.normal => Colors.transparent,
      };

  IconData get icon => switch (this) {
        AlertSeverity.extreme => Icons.flood_rounded,
        AlertSeverity.critical => Icons.warning_amber_rounded,
        AlertSeverity.danger => Icons.water_rounded,
        AlertSeverity.rising => Icons.trending_up_rounded,
        AlertSeverity.normal => Icons.check_circle_outline_rounded,
      };

  // null = never auto-dismiss
  int? get autoDismissSeconds => switch (this) {
        AlertSeverity.extreme => null,
        AlertSeverity.critical => null,
        AlertSeverity.danger => 120,
        AlertSeverity.rising => 60,
        AlertSeverity.normal => 30,
      };
}

// ── LiveAlertBanner ─────────────────────────────────────────────────────────
class LiveAlertBanner extends StatefulWidget {
  const LiveAlertBanner({
    super.key,
    required this.alert,
    this.onTap,
    this.onDismiss,
  });

  final AlertItem alert;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  @override
  State<LiveAlertBanner> createState() => _LiveAlertBannerState();
}

class _LiveAlertBannerState extends State<LiveAlertBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    final secs = widget.alert.severity.autoDismissSeconds;
    if (secs != null) {
      Future.delayed(Duration(seconds: secs), _dismiss);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted || _dismissed) return;
    setState(() => _dismissed = true);
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final alert = widget.alert;
    final sev = alert.severity;
    final c = sev.color(context);
    final glow = sev.glowColor(context);
    final icon = sev.icon;

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap?.call();
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withValues(alpha: 0.50), width: 1.4),
            boxShadow: [
              BoxShadow(color: glow, blurRadius: 12, spreadRadius: 1),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Pulsing icon ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Opacity(
                    opacity: _pulseAnim.value,
                    child: Icon(icon, color: c, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // ── Text column ───────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primary message + source badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.message,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _SourceBadge(
                            source: alert.source, isLive: alert.isLive),
                      ],
                    ),
                    // Sub-message (level detail)
                    if (alert.subMessage != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        alert.subMessage!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppPalette.textGrey,
                          height: 1.3,
                        ),
                      ),
                    ],
                    // Rate-of-rise chip
                    if ((alert.rateOfRiseMph ?? 0) >= 0.3) ...[
                      const SizedBox(height: 5),
                      _RorChip(ror: alert.rateOfRiseMph!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // ── Right column: arrow + dismiss ─────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onTap != null)
                    Icon(Icons.arrow_forward_ios_rounded,
                        color: c.withValues(alpha: 0.75), size: 13),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppPalette.textGrey,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Source badge ──────────────────────────────────────────────────────────────
class _SourceBadge extends StatelessWidget {
  final String source;
  final bool isLive;
  const _SourceBadge({required this.source, required this.isLive});

  @override
  Widget build(BuildContext context) {
    final label = isLive ? 'LIVE' : 'EST';
    final bg = isLive
        ? const Color(0xFF1B5E20).withValues(alpha: 0.85)
        : const Color(0xFF4A4A4A).withValues(alpha: 0.75);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Rate-of-rise chip ─────────────────────────────────────────────────────────
class _RorChip extends StatelessWidget {
  final double ror;
  const _RorChip({required this.ror});

  @override
  Widget build(BuildContext context) {
    final urgent = ror >= 1.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: (urgent ? const Color(0xFFD32F2F) : const Color(0xFFE65100))
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (urgent ? const Color(0xFFD32F2F) : const Color(0xFFE65100))
              .withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.trending_up_rounded,
            size: 11,
            color: urgent ? const Color(0xFFD32F2F) : const Color(0xFFE65100),
          ),
          const SizedBox(width: 3),
          Text(
            '+${ror.toStringAsFixed(2)} m/h',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: urgent ? const Color(0xFFD32F2F) : const Color(0xFFE65100),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AlertSeverityBannerList — production-ready consumer ───────────────────────
// Drop this anywhere in the widget tree to show live alert cards.
// Automatically listens to ActiveAlertController.stream.
class AlertSeverityBannerList extends StatelessWidget {
  const AlertSeverityBannerList({
    super.key,
    this.onTapAlert,
  });

  /// Optional tap handler. Receives the tapped AlertItem.
  final void Function(AlertItem)? onTapAlert;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AlertItem>>(
      stream: ActiveAlertController.instance.stream,
      initialData: ActiveAlertController.instance.alerts,
      builder: (context, snap) {
        final alerts = snap.data ?? [];
        if (alerts.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: alerts
              .map((a) => LiveAlertBanner(
                    key: ValueKey('alert_${a.stationKey}'),
                    alert: a,
                    onTap: onTapAlert != null ? () => onTapAlert!(a) : null,
                    onDismiss: () {
                      // Locally dismissed — no state change in controller;
                      // will re-appear on next cycle if still alerting.
                    },
                  ))
              .toList(),
        );
      },
    );
  }
}
