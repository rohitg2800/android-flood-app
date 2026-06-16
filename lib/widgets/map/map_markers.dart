// lib/widgets/map/map_markers.dart  v2.1
// PulseMarker      — animated red/orange ring for CRITICAL / SEVERE stations.
// AmberPulseMarker — softer amber pulse for WARNING (aboveNormal) stations.
// StaticMarker     — plain dot for NORMAL stations.
// v2.1: added AmberPulseMarker; aboveNormal stations now pulse amber
//       instead of showing a dull static dot.
import 'package:flutter/material.dart';
import '../../models/river_station.dart'; // DangerClass
import 'map_risk_helpers.dart';

// ── helpers ────────────────────────────────────────────────────────────────────

IconData _iconFor(DangerClass dc) {
  switch (dc) {
    case DangerClass.extreme:     return Icons.flood_rounded;
    case DangerClass.severe:      return Icons.warning_rounded;
    case DangerClass.aboveNormal: return Icons.water_rounded;
    case DangerClass.normal:      return Icons.water_drop_rounded;
  }
}

// ── PulseMarker ───────────────────────────────────────────────────────────────
/// Used for CRITICAL (extreme) and SEVERE stations.
class PulseMarker extends StatelessWidget {
  final DangerClass dangerClass;
  final AnimationController ctrl;
  final String? level;

  /// v2.2: ensures pulse frequency is animation-controller driven.
  const PulseMarker({
    super.key,
    required this.dangerClass,
    required this.ctrl,
    this.level,
  });

  @override
  Widget build(BuildContext context) {
    final color = riskColorSolid(dangerClass);
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final scale = 1.0 + 0.35 * ctrl.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:  color.withValues(alpha: 0.15 * (1 - ctrl.value)),
                      border: Border.all(
                        color: color.withValues(alpha: 0.4 * (1 - ctrl.value)),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color:      color.withValues(alpha: 0.55),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Icon(
                    _iconFor(dangerClass),
                    color: Colors.white,
                    size:  13,
                  ),
                ),
              ],
            ),
            if (level != null && level!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color:        color,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color:      color.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  level!,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   8,
                    fontWeight: FontWeight.w700,
                    height:     1.2,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── AmberPulseMarker ──────────────────────────────────────────────────────────
/// Softer amber pulse for WARNING (aboveNormal) stations.
/// Smaller ring and lower opacity than PulseMarker to distinguish from CRITICAL.
class AmberPulseMarker extends StatelessWidget {
  final AnimationController ctrl;
  final String? level;

  /// v2.2: Uses theme risk tokens.
  const AmberPulseMarker({
    super.key,
    required this.ctrl,
    this.level,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFFBC02D); // amber
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final scale = 1.0 + 0.22 * ctrl.value; // gentler than CRITICAL pulse
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:  color.withValues(
                          alpha: 0.12 * (1 - ctrl.value)),
                      border: Border.all(
                        color: color.withValues(
                            alpha: 0.35 * (1 - ctrl.value)),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color:      color.withValues(alpha: 0.45),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.water_rounded,
                    color: Colors.white,
                    size:  12,
                  ),
                ),
              ],
            ),
            if (level != null && level!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color:        color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  level!,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   8,
                    fontWeight: FontWeight.w700,
                    height:     1.2,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── StaticMarker ────────────────────────────────────────────────────────────────
/// Used for NORMAL stations only.
class StaticMarker extends StatelessWidget {
  final DangerClass dangerClass;
  final String?     level;
  final bool        isLive;

  const StaticMarker({
    super.key,
    required this.dangerClass,
    this.level,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = riskColorSolid(dangerClass);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.88),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.65), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.35), blurRadius: 6),
                ],
              ),
              child: Icon(
                _iconFor(dangerClass),
                color: Colors.white,
                size:  14,
              ),
            ),
            if (isLive)
              Positioned(
                top:   -2,
                right: -2,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF00E676),
                    boxShadow: [
                      BoxShadow(color: Color(0x8000E676), blurRadius: 4),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (level != null && level!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              level!,
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   8,
                fontWeight: FontWeight.w600,
                height:     1.2,
              ),
            ),
          ),
      ],
    );
  }
}
