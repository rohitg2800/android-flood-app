#!/bin/bash

mkdir -p lib/core/theme
mkdir -p lib/core/routing
mkdir -p lib/core/widgets

cat <<'EOF' > lib/core/theme/high_contrast_colors.dart
import 'package:flutter/material.dart';
import 'river_colors.dart';

class HighContrastColors {
  static RiverColors from(RiverColors base) {
    return RiverColors(
      scaffoldBg: const Color(0xFF000000),
      cardBg: const Color(0xFF0A0A0A),
      surfaceOutline: const Color(0xFF4A5568),
      textPrimary: const Color(0xFFFFFFFF),
      textSecondary: const Color(0xFFE2E8F0),
      textMuted: const Color(0xFFA0AEC0),
      accent: const Color(0xFF63C2FF),
      accentSoft: const Color(0x4D63C2FF),
      danger: const Color(0xFFFF6B75),
      warning: const Color(0xFFFFD874),
      success: const Color(0xFF48D597),
      info: const Color(0xFF7B8FFF),
    );
  }
}
EOF

cat <<'EOF' > lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'river_colors.dart';
import 'high_contrast_colors.dart';

class AppTheme {
  final RiverColors colors;
  final bool highContrast;

  const AppTheme({required this.colors, required this.highContrast});

  factory AppTheme.dark({bool highContrast = false}) {
    final base = RiverColors.dark();
    final colors = highContrast ? HighContrastColors.from(base) : base;
    return AppTheme(colors: colors, highContrast: highContrast);
  }

  ThemeData toThemeData() {
    final c = colors;
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: c.scaffoldBg,
      cardColor: c.cardBg,
      dividerColor: c.surfaceOutline,
      colorScheme: ColorScheme.dark(
        background: c.scaffoldBg,
        surface: c.cardBg,
        primary: c.accent,
        secondary: c.info,
        error: c.danger,
        outline: c.surfaceOutline,
      ),
      textTheme: TextTheme(
        titleMedium: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.5),
        bodyMedium: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
        labelMedium: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.4),
        labelSmall: TextStyle(color: c.textMuted, fontSize: 11, letterSpacing: 0.9, fontWeight: FontWeight.w600),
      ),
      iconTheme: IconThemeData(color: c.textSecondary, size: 20),
      splashColor: c.accentSoft,
      highlightColor: Colors.transparent,
    );
  }
}
EOF

cat <<'EOF' > lib/core/theme/river_theme.dart
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'river_colors.dart';

class RiverTheme extends InheritedWidget {
  final AppTheme appTheme;

  const RiverTheme({super.key, required this.appTheme, required super.child});

  RiverColors get colors => appTheme.colors;

  static RiverTheme of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<RiverTheme>();
    assert(result != null, 'No RiverTheme found in context.');
    return result!;
  }

  static RiverTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RiverTheme>();

  @override
  bool updateShouldNotify(RiverTheme old) =>
      old.appTheme.colors != appTheme.colors ||
      old.appTheme.highContrast != appTheme.highContrast;
}
EOF

cat <<'EOF' > lib/core/theme/index.dart
export 'river_colors.dart';
export 'app_theme.dart';
export 'river_theme.dart';
export 'high_contrast_colors.dart';
EOF

cat <<'EOF' > lib/core/routing/app_routes.dart
class AppRoutes {
  AppRoutes._();
  static const splash        = '/';
  static const onboarding    = '/onboarding';
  static const dashboard     = '/dashboard';
  static const mapBihar      = '/map/bihar';
  static const alerts        = '/alerts';
  static const sos           = '/sos';
  static const settings      = '/settings';
  static const accessibility = '/settings/accessibility';
  static const profile       = '/profile';
}
EOF

cat <<'EOF' > lib/core/routing/app_router.dart
import 'package:flutter/material.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      default:
        return _fade(const Scaffold(
          body: Center(child: Text('Route not found')),
        ));
    }
  }

  static PageRoute<T> _fade<T>(Widget child) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => child,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
        child: child,
      ),
    );
  }

  static PageRoute<T> _slideUp<T>(Widget child) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => child,
      transitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (_, animation, __, child) {
        final offset = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(animation);
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: SlideTransition(position: offset, child: child),
        );
      },
    );
  }
}
EOF

cat <<'EOF' > lib/core/routing/index.dart
export 'app_routes.dart';
export 'app_router.dart';
EOF

cat <<'EOF' > lib/core/widgets/ops_card.dart
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class OpsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double radius;

  const OpsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.borderColor,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final c = RiverTheme.of(context).colors;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.surfaceOutline),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        splashColor: c.accentSoft,
        child: content,
      ),
    );
  }
}
EOF

cat <<'EOF' > lib/core/widgets/ops_section_header.dart
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class OpsSectionHeader extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? trailing;

  const OpsSectionHeader({super.key, required this.label, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = RiverTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 15, color: c.textMuted), const SizedBox(width: 6)],
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.textMuted, letterSpacing: 1.0, fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
EOF

cat <<'EOF' > lib/core/widgets/ops_pill_chip.dart
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class OpsPillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? activeColor;

  const OpsPillChip({super.key, required this.label, this.selected = false, this.onTap, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final c = RiverTheme.of(context).colors;
    final active = activeColor ?? c.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? active.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? active : c.surfaceOutline),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? active : c.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
        ),
      ),
    );
  }
}
EOF

cat <<'EOF' > lib/core/widgets/ops_badge.dart
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

enum OpsBadgeVariant { danger, warning, success, info, neutral }

class OpsBadge extends StatelessWidget {
  final String label;
  final OpsBadgeVariant variant;

  const OpsBadge({super.key, required this.label, this.variant = OpsBadgeVariant.neutral});

  @override
  Widget build(BuildContext context) {
    final c = RiverTheme.of(context).colors;
    final Color base = switch (variant) {
      OpsBadgeVariant.danger  => c.danger,
      OpsBadgeVariant.warning => c.warning,
      OpsBadgeVariant.success => c.success,
      OpsBadgeVariant.info    => c.info,
      OpsBadgeVariant.neutral => c.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: base.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: base.withOpacity(0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: base, letterSpacing: 0.7),
      ),
    );
  }
}
EOF

cat <<'EOF' > lib/core/widgets/ops_banner.dart
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
          color: base.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: base.withOpacity(0.30)),
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
EOF

cat <<'EOF' > lib/core/widgets/index.dart
export 'ops_card.dart';
export 'ops_section_header.dart';
export 'ops_pill_chip.dart';
export 'ops_badge.dart';
export 'ops_banner.dart';
EOF

cat <<'EOF' > lib/core/index.dart
export 'theme/index.dart';
export 'routing/index.dart';
export 'widgets/index.dart';
EOF

echo "✅ core/ scaffold complete"
