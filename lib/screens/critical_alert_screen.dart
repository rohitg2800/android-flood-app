// lib/screens/critical_alert_screen.dart  v4.0
//
// v4.0 (14 Jun 2026) — Glassmorphic alert banner
//
//   Design:
//     • BackdropFilter(ImageFilter.blur) — true frosted-glass effect that
//       blurs whatever is behind the card (map, dashboard, any screen).
//     • Semi-transparent gradient overlay (white+red/orange tint) on the
//       blur for depth and colour identity.
//     • Animated glowing border — danger colour pulses via an
//       AnimationController so the card is impossible to miss.
//     • Neon CRITICAL / DANGER badge with pulsing opacity.
//     • Level progress bar: filled proportion = current / danger level.
//     • White text + drop-shadow — readable on light AND dark backgrounds.
//     • Slide-in with elasticOut spring curve for a snappy entrance.
//     • ClipRRect wrapping BackdropFilter so blur is clipped to rounded
//       corners (without this, blur bleeds to a rectangle outside the card).
//
//   Retained from v3.1:
//     • OverlayEntry (non-blocking, interactive background)
//     • ClipRect to prevent slide overflow painting
//     • One-at-a-time dedup via _activeBannerEntry
//     • 12-second auto-dismiss + swipe-down + ✕ button
//     • "View Map" / "Evacuate" CTAs

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

// ── public API ────────────────────────────────────────────────────────────────
void showCriticalAlertOverlay(
  BuildContext context, {
  required String        stationName,
  required String        riverName,
  required double        currentLevel,
  required double        dangerLevel,
  required String        district,
  required VoidCallback  onViewMap,
  required VoidCallback  onEvacuate,
}) {
  showCriticalAlertBanner(
    context,
    stationName:  stationName,
    riverName:    riverName,
    currentLevel: currentLevel,
    dangerLevel:  dangerLevel,
    district:     district,
    onViewMap:    onViewMap,
    onEvacuate:   onEvacuate,
  );
}

// ── singleton guard ───────────────────────────────────────────────────────────
OverlayEntry? _activeBannerEntry;

void showCriticalAlertBanner(
  BuildContext context, {
  required String        stationName,
  required String        riverName,
  required double        currentLevel,
  required double        dangerLevel,
  required String        district,
  required VoidCallback  onViewMap,
  required VoidCallback  onEvacuate,
}) {
  _activeBannerEntry?.remove();
  _activeBannerEntry = null;

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (overlayContext) {
      final mq           = MediaQuery.of(overlayContext);
      final bottomOffset = mq.padding.bottom + kBottomNavigationBarHeight + 12.0;

      return Positioned.fill(
        child: Stack(
          children: [
            // Full-screen transparent pass-through
            const Positioned.fill(
              child: IgnorePointer(ignoring: true, child: SizedBox.expand()),
            ),
            // Glassy banner anchored above bottom-nav
            Positioned(
              left:   0,
              right:  0,
              bottom: bottomOffset,
              child: _CriticalBanner(
                stationName:  stationName,
                riverName:    riverName,
                currentLevel: currentLevel,
                dangerLevel:  dangerLevel,
                district:     district,
                onViewMap: () { _dismiss(entry); onViewMap(); },
                onEvacuate: () { _dismiss(entry); onEvacuate(); },
                onDismiss:  () => _dismiss(entry),
              ),
            ),
          ],
        ),
      );
    },
  );

  _activeBannerEntry = entry;
  overlay.insert(entry);
}

void _dismiss(OverlayEntry entry) {
  if (_activeBannerEntry == entry) _activeBannerEntry = null;
  try { entry.remove(); } catch (_) {}
}

// ── Animated banner host ──────────────────────────────────────────────────────
class _CriticalBanner extends StatefulWidget {
  final String        stationName;
  final String        riverName;
  final double        currentLevel;
  final double        dangerLevel;
  final String        district;
  final VoidCallback  onViewMap;
  final VoidCallback  onEvacuate;
  final VoidCallback  onDismiss;

  const _CriticalBanner({
    required this.stationName,
    required this.riverName,
    required this.currentLevel,
    required this.dangerLevel,
    required this.district,
    required this.onViewMap,
    required this.onEvacuate,
    required this.onDismiss,
  });

  @override
  State<_CriticalBanner> createState() => _CriticalBannerState();
}

class _CriticalBannerState extends State<_CriticalBanner>
    with TickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _glow;
  Timer? _autoTimer;

  static const _autoDismiss = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 480),
    );
    // Dampened spring — snappy slide-in that settles quickly
    _slide = Tween<Offset>(
      begin: const Offset(0, 1.2),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve:  Curves.easeOutBack,
    ));

    _glowCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _slideCtrl.forward();
    _autoTimer = Timer(_autoDismiss, () {
      if (mounted) _animatedDismiss();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _slideCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _animatedDismiss() {
    _autoTimer?.cancel();
    _slideCtrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 150) _animatedDismiss();
      },
      child: ClipRect(
        child: SlideTransition(
          position: _slide,
          child: AnimatedBuilder(
            animation: _glow,
            builder: (_, child) => _GlassCard(
              stationName:  widget.stationName,
              riverName:    widget.riverName,
              currentLevel: widget.currentLevel,
              dangerLevel:  widget.dangerLevel,
              district:     widget.district,
              glowStrength: _glow.value,
              onViewMap:    widget.onViewMap,
              onEvacuate:   widget.onEvacuate,
              onDismiss:    _animatedDismiss,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Glassmorphic card ─────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final String        stationName;
  final String        riverName;
  final double        currentLevel;
  final double        dangerLevel;
  final String        district;
  final double        glowStrength;   // 0.4 … 1.0, drives border + shadow pulse
  final VoidCallback  onViewMap;
  final VoidCallback  onEvacuate;
  final VoidCallback  onDismiss;

  const _GlassCard({
    required this.stationName,
    required this.riverName,
    required this.currentLevel,
    required this.dangerLevel,
    required this.district,
    required this.glowStrength,
    required this.onViewMap,
    required this.onEvacuate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final aboveDl  = currentLevel - dangerLevel;
    final isAbove  = aboveDl >= 0;
    final accent   = isAbove ? const Color(0xFFFF1744) : const Color(0xFFFF6D00);
    final fillPct  = (dangerLevel > 0
        ? (currentLevel / dangerLevel).clamp(0.0, 1.5)
        : 0.0);

    // Glow shadow colour driven by animation
    final glowColor = accent.withValues(alpha: 0.55 * glowStrength);
    final borderColor = accent.withValues(alpha: 0.5 + 0.5 * glowStrength);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      // ClipRRect is REQUIRED so BackdropFilter blur is clipped to the
      // rounded corners — without this the blur rectangle is rectangular
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Layer 1: backdrop blur (the actual glassmorphism) ──────────
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                decoration: BoxDecoration(
                  // Frosted glass base: mostly transparent white tinted by accent
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.13),
                      accent.withValues(alpha: 0.09),
                      Colors.black.withValues(alpha: 0.35),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // ── Layer 2: animated glowing border + shadow ─────────────────
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.6),
                boxShadow: [
                  BoxShadow(
                    color:        glowColor,
                    blurRadius:   28 * glowStrength,
                    spreadRadius: 2  * glowStrength,
                  ),
                  BoxShadow(
                    color:        accent.withValues(alpha: 0.12),
                    blurRadius:   6,
                    offset:       const Offset(0, 3),
                  ),
                ],
              ),
            ),

            // ── Layer 3: card content ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Header row
                  Row(
                    children: [
                      // Pulsing badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:        accent.withValues(alpha: 0.22 * glowStrength + 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border:       Border.all(
                              color: accent.withValues(alpha: 0.7), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color:      accent.withValues(alpha: 0.4 * glowStrength),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_rounded,
                                color: accent, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              isAbove ? '⚠ CRITICAL' : '⚠ DANGER',
                              style: TextStyle(
                                color:       accent,
                                fontSize:    10,
                                fontWeight:  FontWeight.w900,
                                letterSpacing: 0.9,
                                shadows: [
                                  Shadow(
                                    color: accent.withValues(alpha: 0.8),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          stationName,
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   13,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(
                                color:      Colors.black54,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onDismiss,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color:        Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white70, size: 16),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  // River · district
                  Text(
                    '${riverName}  ·  ${district.isNotEmpty ? district : "Bihar"}',
                    style: const TextStyle(
                      color:      Colors.white70,
                      fontSize:   11,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Level line
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12),
                      children: [
                        TextSpan(
                          text: '${currentLevel.toStringAsFixed(2)} m  ',
                          style: TextStyle(
                            color:      accent,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(
                                color:      accent.withValues(alpha: 0.7),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        TextSpan(
                          text: isAbove
                              ? '(+${aboveDl.toStringAsFixed(2)} m above DL '
                                  '${dangerLevel.toStringAsFixed(2)} m)'
                              : '(DL ${dangerLevel.toStringAsFixed(2)} m)',
                          style: const TextStyle(
                            color:   Colors.white60,
                            shadows: [Shadow(color: Colors.black38, blurRadius: 3)],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Progress bar
                  _LevelBar(
                    fillFraction: fillPct,
                    color:        accent,
                    glowStrength: glowStrength,
                  ),

                  const SizedBox(height: 10),

                  // Action row
                  Row(
                    children: [
                      _GlassBtn(
                        label: 'View Map',
                        icon:  Icons.map_outlined,
                        color: const Color(0xFF29B6F6),
                        onTap: onViewMap,
                      ),
                      const SizedBox(width: 8),
                      _GlassBtn(
                        label: 'Evacuate',
                        icon:  Icons.directions_run_rounded,
                        color: accent,
                        onTap: onEvacuate,
                      ),
                      const Spacer(),
                      const Flexible(
                        child: Text(
                          'Swipe ↓ to dismiss',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white30, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Level progress bar ────────────────────────────────────────────────────────
class _LevelBar extends StatelessWidget {
  final double fillFraction;
  final Color  color;
  final double glowStrength;

  const _LevelBar({
    required this.fillFraction,
    required this.color,
    required this.glowStrength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Water level vs danger level',
              style: TextStyle(color: Colors.white38, fontSize: 9),
            ),
            Text(
              '${(fillFraction * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color:      color,
                fontSize:   9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              // Track
              Container(
                height:     6,
                color:      Colors.white.withValues(alpha: 0.12),
              ),
              // Fill
              FractionallySizedBox(
                widthFactor: fillFraction.clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.7),
                        color,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:      color.withValues(alpha: 0.6 * glowStrength),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Glass action button ───────────────────────────────────────────────────────
class _GlassBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  const _GlassBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
              border:       Border.all(
                  color: color.withValues(alpha: 0.55), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 13),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color:       color,
                    fontSize:    11,
                    fontWeight:  FontWeight.w700,
                    shadows: [
                      Shadow(
                        color:      color.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }
}
