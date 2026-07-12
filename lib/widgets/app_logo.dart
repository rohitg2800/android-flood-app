// lib/widgets/app_logo.dart
// EQUINOX-BH — Module 2: Branding & Icons
//
// AppLogo widget — reusable branded logo component
//   • Renders the OpsFlood SVG wordmark or compact wave glyph
//   • Supports three variants: full (wordmark + tagline), compact (wave + "OpsFlood"), icon (wave only)
//   • Automatically picks light/dark tint from theme context
//   • Used in: splash bridging widget, onboarding_screen, main_shell drawer header, about screen
//
// Usage:
//   AppLogo(variant: LogoVariant.full, height: 48)
//   AppLogo(variant: LogoVariant.compact, height: 32)
//   AppLogo(variant: LogoVariant.icon, height: 24)

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/river_theme.dart';

/// Controls which form of the logo is rendered.
enum LogoVariant {
  /// Full SVG wordmark: wave glyph + "OPS" + "FLOOD" + tagline.
  full,

  /// Compact: wave glyph + "OpsFlood" text in a Row.
  compact,

  /// Icon only: wave glyph (square aspect ratio).
  icon,
}

class AppLogo extends StatelessWidget {
  final LogoVariant variant;

  /// Target height in logical pixels. Width is derived from the SVG aspect ratio.
  final double height;

  /// Override tint colour. Defaults to [RiverColors.accent] from the current theme.
  final Color? color;

  const AppLogo({
    super.key,
    this.variant = LogoVariant.compact,
    this.height = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final tint = color ?? t.accent;

    switch (variant) {
      case LogoVariant.full:
        // Full SVG wordmark — 200×48 intrinsic size
        return SvgPicture.asset(
          'assets/icons/ic_opsflood_wordmark.svg',
          height: height,
          colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
          semanticsLabel: 'OpsFlood — Bihar Flood Intelligence',
        );

      case LogoVariant.compact:
        // Wave icon + text side by side
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/ic_wave.svg',
              height: height,
              width: height,
              colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
              semanticsLabel: 'OpsFlood wave logo',
            ),
            SizedBox(width: height * 0.3),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Ops',
                    style: TextStyle(
                      color: tint,
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.w700,
                      fontSize: height * 0.6,
                      letterSpacing: 0.5,
                    ),
                  ),
                  TextSpan(
                    text: 'Flood',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.w700,
                      fontSize: height * 0.6,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case LogoVariant.icon:
        // Just the wave glyph — square
        return SvgPicture.asset(
          'assets/icons/ic_wave.svg',
          height: height,
          width: height,
          colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
          semanticsLabel: 'OpsFlood',
        );
    }
  }
}

// ── OpsFloodSplashBridge ─────────────────────────────────────────────────────
//
// Drop-in splash bridge widget placed in main.dart while Firebase/providers
// initialise. Fades from the native splash colour (#0d1b2a) into the app.
// Replace the current placeholder Container in your MaterialApp builder with:
//
//   home: OpsFloodSplashBridge(child: MainShell()),
//
// ────────────────────────────────────────────────────────────────────────────

class OpsFloodSplashBridge extends StatefulWidget {
  final Widget child;
  const OpsFloodSplashBridge({super.key, required this.child});

  @override
  State<OpsFloodSplashBridge> createState() => _OpsFloodSplashBridgeState();
}

class _OpsFloodSplashBridgeState extends State<OpsFloodSplashBridge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    // Brief hold so native splash transitions feel smooth, then fade in
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _ready = true);
        _ctrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Pixel-perfect match to native splash background
      return const ColoredBox(
        color: Color(0xFF0D1B2A),
        child: Center(
          child: AppLogo(variant: LogoVariant.compact, height: 40),
        ),
      );
    }
    return FadeTransition(opacity: _fade, child: widget.child);
  }
}
