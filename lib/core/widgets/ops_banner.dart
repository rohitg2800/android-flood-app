import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

enum OpsBannerVariant { danger, warning, info, success }

class OpsBanner extends StatelessWidget {
  final String title;
  final String? subtitle;
  final OpsBannerVariant variant;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const OpsBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.variant = OpsBannerVariant.info,
    this.icon,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final c = RiverTheme.of(context).colors;
    final Color base = switch (variant) {
      OpsBannerVariant.danger  => c.danger,
      OpsBannerVariant.warning => c.warning,
      OpsBannerVariant.success => c.success,
      OpsBannerVariant.info    => c.info,
    };
    final IconData defaultIcon = switch (variant) {
      OpsBannerVariant.danger  => Icons.warning_amber_rounded,
      OpsBannerVariant.warning => Icons.info_outline_rounded,
      OpsBannerVariant.success => Icons.check_circle_outline_rounded,
      OpsBannerVariant.info    => Icons.notifications_none_rounded,
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: base.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Icon(icon ?? defaultIcon, color: base, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: base, fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: c.textSecondary)),
                ],
              ),
            ),
            if (onDismiss != null)
              GestureDetector(
                  onTap: onDismiss,
                  child: Icon(Icons.close_rounded, color: c.textMuted, size: 18)),
          ],
        ),
      ),
    );
  }
}
