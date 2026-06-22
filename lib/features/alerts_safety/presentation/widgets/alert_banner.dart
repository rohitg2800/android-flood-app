import "package:flutter/material.dart";
import "package:equinox_flood/core/theme/river_theme.dart" as core_theme;

enum AlertBannerSeverity { emergency, critical, warning, info }

class AlertBanner extends StatelessWidget {
  final String title;
  final String? subtitle;
  final AlertBannerSeverity severity;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const AlertBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.severity = AlertBannerSeverity.info,
    this.onTap,
    this.onDismiss,
  });

  Color _color(dynamic c) {
    switch (severity) {
      case AlertBannerSeverity.emergency: return c.danger;
      case AlertBannerSeverity.critical:  return c.danger;
      case AlertBannerSeverity.warning:   return c.warning;
      case AlertBannerSeverity.info:      return c.info;
    }
  }

  IconData _icon() {
    switch (severity) {
      case AlertBannerSeverity.emergency: return Icons.crisis_alert_rounded;
      case AlertBannerSeverity.critical:  return Icons.warning_amber_rounded;
      case AlertBannerSeverity.warning:   return Icons.info_outline_rounded;
      case AlertBannerSeverity.info:      return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c     = core_theme.RiverTheme.of(context).colors;
    final color = _color(c);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.30)),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon(), color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!,
                      style: TextStyle(color: c.textSecondary, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: color, size: 18),
            if (onDismiss != null)
              GestureDetector(
                onTap: onDismiss,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.close_rounded, color: c.textSecondary, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}