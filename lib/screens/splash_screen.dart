// lib/screens/splash_screen.dart
// OpsFlood — SplashScreen v5
//
// After the boot animation completes:
//   • If onboarding not done  → /onboarding
//   • Otherwise               → /shell
//
// v5 fixes: use context.go() (GoRouter) instead of the legacy
//   Navigator.pushReplacementNamed API, which requires onGenerateRoute
//   and crashes when the app is wired with MaterialApp.router.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_router.dart';
import '../providers/onboarding_provider.dart';
import '../theme/river_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  static const String route = '/';
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ring;
  late final AnimationController _text;
  late final Animation<double>    _ringScale;
  late final Animation<double>    _ringOpacity;
  late final Animation<double>    _textOpacity;
  late final Animation<Offset>    _textSlide;

  @override
  void initState() {
    super.initState();

    _ring = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _text = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _ringScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _ring, curve: Curves.easeOutBack));
    _ringOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _ring,
            curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _text, curve: Curves.easeIn));
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _text, curve: Curves.easeOutCubic));

    _ring.forward().then((_) {
      _text.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 500), _navigate);
      });
    });
  }

  Future<void> _navigate() async {
    // ── Determine if onboarding is done ──────────────────────────────────────
    // .future only resolves on AsyncData; it hangs forever on AsyncError.
    // Add a 3-second safety timeout and a catch so the splash ALWAYS exits.
    bool done = false;
    try {
      done = await ref
          .read(onboardingProvider.future)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // AsyncError OR timeout: default to shell so the user isn't locked out.
      // On next launch SharedPreferences will be healthy and routing is correct.
      done = true;
    }

    if (!mounted) return;

    // Use addPostFrameCallback so the GoRouter navigation happens after the
    // current frame is fully painted (eliminates cold-boot assertion).
    // context.go() is the correct GoRouter API — pushReplacementNamed
    // requires onGenerateRoute which MaterialApp.router does NOT provide.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(done ? Routes.shell : Routes.onboarding);
    });
  }

  @override
  void dispose() {
    _ring.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated ring + icon
            AnimatedBuilder(
              animation: _ring,
              builder: (_, __) => Opacity(
                opacity: _ringOpacity.value,
                child: Transform.scale(
                  scale: _ringScale.value,
                  child: _LogoRing(t: t),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Animated title + tagline
            AnimatedBuilder(
              animation: _text,
              builder: (_, __) => Opacity(
                opacity: _textOpacity.value,
                child: SlideTransition(
                  position: _textSlide,
                  child: Column(
                    children: [
                      Text(
                        'EQUINOX',
                        style: TextStyle(
                          color: t.accent,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      Text(
                        'BR-05',
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Flood Intelligence System',
                        style: TextStyle(
                          color: t.textSecondary.withValues(alpha: 0.7),
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated concentric rings logo ───────────────────────────────────────────

class _LogoRing extends StatefulWidget {
  final RiverColors t;
  const _LogoRing({required this.t});

  @override
  State<_LogoRing> createState() => _LogoRingState();
}

class _LogoRingState extends State<_LogoRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer spinning arc
          AnimatedBuilder(
            animation: _spin,
            builder: (_, __) => Transform.rotate(
              angle: _spin.value * 2 * math.pi,
              child: CustomPaint(
                size: const Size(140, 140),
                painter: _ArcPainter(color: t.accent, strokeWidth: 2),
              ),
            ),
          ),
          // Inner glow ring
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: 0.08),
              border: Border.all(
                  color: t.accent.withValues(alpha: 0.28), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: t.accentGlow, blurRadius: 32)
              ],
            ),
          ),
          // Centre icon
          Icon(Icons.flood_rounded, color: t.accent, size: 44),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color  color;
  final double strokeWidth;
  const _ArcPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color.withValues(alpha: 0.55)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round;
    const gap   = 0.25; // radians gap
    const sweep = math.pi * 2 - gap * 2;
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      gap,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => false;
}
