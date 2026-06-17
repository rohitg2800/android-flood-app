// lib/widgets/ops_depth_card.dart
// PHASE 3 — Ops-style alert depth card with severity glow border
library;

import 'package:flutter/material.dart';
import 'app_icon_box.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../theme/app_palette.dart';
import '../theme/river_theme.dart';
import '../services/alert_engine.dart';

/// Card shown in AlertsScreen for each FloodAlert.
/// Shows station name, river, depth bar, severity badge, and time-ago.
///
/// Usage:
/// ```dart
/// OpsDepthCard(alert: alert)
/// ```
class OpsDepthCard extends StatelessWidget {
  final FloodAlert alert;
  final VoidCallback? onTap;

  const OpsDepthCard({super.key, required this.alert, this.onTap});

  // ── Severity → visual config ──────────────────────────────────────────
  static _SevStyle _style(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency:
        return _SevStyle(
          color:  AppPalette.critical,
          label:  'EMERGENCY',
          icon:   Icons.warning_amber_rounded,
          glow:   true,
        );
      case AlertSeverity.critical:
        return _SevStyle(
          color:  AppPalette.danger,
          label:  'CRITICAL',
          icon:   Icons.warning_rounded,
          glow:   true,
        );
      case AlertSeverity.warning:
        return _SevStyle(
          color:  AppPalette.warning,
          label:  'WARNING',
          icon:   Icons.error_outline_rounded,
          glow:   false,
        );
      default:
        return _SevStyle(
          color:  AppPalette.safe,
          label:  'NORMAL',
          icon:   Icons.check_circle_outline_rounded,
          glow:   false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final sev   = _style(alert.severity);
    final pct   = (alert.currentLevel /
            (alert.thresholdLevel > 0 ? alert.thresholdLevel : alert.currentLevel * 1.2))
        .clamp(0.0, 1.0);
    final when  = timeago.format(alert.issuedAt);         // ✅ was triggeredAt

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.abyss2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sev.glow
                ? sev.color.withValues(alpha: 0.65)
                : AppPalette.abyssStroke,
            width: sev.glow ? 1.5 : 1.0,
          ),
          boxShadow: sev.glow
              ? [
                  BoxShadow(
                    color:       sev.color.withValues(alpha: 0.18),
                    blurRadius:  12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────
              Row(
                children: [
                  AppIconBox.small(icon: sev.icon, color: sev.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.title,
                      style: TextStyle(
                        color:      t.textPrimary,
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _SeverityChip(label: sev.label, color: sev.color),
                ],
              ),
              const SizedBox(height: 4),

              // ── River + district ────────────────────────────────────
              Text(
                '${alert.river}  •  ${alert.district}', // ✅ river (not riverName), district non-nullable
                style: const TextStyle(
                    color: AppPalette.textGrey, fontSize: 12),
              ),
              const SizedBox(height: 10),

              // ── Depth progress bar ──────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${alert.currentLevel.toStringAsFixed(2)} m',
                              style: TextStyle(
                                color:      sev.color,
                                fontSize:   18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${(pct * 100).toStringAsFixed(0)}% of threshold',
                              style: const TextStyle(
                                  color:    AppPalette.textGrey,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value:           pct,
                            minHeight:       6,
                            backgroundColor:
                                AppPalette.abyss4.withValues(alpha: 0.5),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(sev.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Footer: body + time-ago ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      alert.body ?? alert.message,                         // ✅ was message
                      style: TextStyle(
                          color:    t.textSecondary,
                          fontSize: 11,
                          height:   1.4),
                      maxLines:  2,
                      overflow:  TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    when,
                    style: const TextStyle(
                        color:    AppPalette.textGrey,
                        fontSize: 10),
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

// ── Internal helpers ──────────────────────────────────────────────────────────

class _SevStyle {
  final Color    color;
  final String   label;
  final IconData icon;
  final bool     glow;
  const _SevStyle({
    required this.color,
    required this.label,
    required this.icon,
    required this.glow,
  });
}

class _SeverityChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _SeverityChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      color,
          fontSize:   10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
