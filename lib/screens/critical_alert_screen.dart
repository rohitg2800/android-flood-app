// lib/screens/critical_alert_screen.dart  v3.1
//
// v3.1 (14 Jun 2026) — Banner-only fix
//
//   BUG (v3.0):
//     The OverlayEntry content was a bare Positioned() whose child
//     (SlideTransition → _BannerCard) still caused a full-screen red flash
//     on the FIRST render frame, before the Offset(0,1) slide translation
//     was painted.  Root cause: OverlayEntry fills the full Overlay by
//     default; the dark-red Material background inside _BannerCard was
//     therefore visible at full height momentarily.
//
//   FIX (v3.1):
//     • Wrap the OverlayEntry body in a transparent, non-absorbing Stack
//       so the overlay has no background and pointer events pass through
//       any area outside the banner card.
//     • Add ClipRect around the SlideTransition so the card is clipped
//       to its Positioned bounds during animation — no overflow painting.
//     • Replace Material() (which set a full-height background) with a
//       plain Container + BoxDecoration so the visual chrome is scoped
//       to the card's intrinsic size only.
//     • Bottom offset updated: banner now sits 8 dp above the bottom-nav
//       (≈ 56 dp tall) plus system padding, giving a tighter / more
//       notification-like appearance.
//
//   All other behaviour unchanged:
//     • OverlayEntry (non-blocking)
//     • 12-second auto-dismiss
//     • Swipe-down / ✕ dismiss
//     • One-at-a-time deduplication via _activeBannerEntry
//     • "View Map" / "Evacuate" CTAs

import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

// ── public API (drop-in replacement) ─────────────────────────────────────────
void showCriticalAlertOverlay(
  BuildContext context, {
  required String   stationName,
  required String   riverName,
  required double   currentLevel,
  required double   dangerLevel,
  required String   district,
  required VoidCallback onViewMap,
  required VoidCallback onEvacuate,
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

// ── singleton guard ────────────────────────────────────────────────────────────
OverlayEntry? _activeBannerEntry;

void showCriticalAlertBanner(
  BuildContext context, {
  required String   stationName,
  required String   riverName,
  required double   currentLevel,
  required double   dangerLevel,
  required String   district,
  required VoidCallback onViewMap,
  required VoidCallback onEvacuate,
}) {
  _activeBannerEntry?.remove();
  _activeBannerEntry = null;

  final overlay = Overlay.of(context);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) {
      final mq = MediaQuery.of(overlayContext);
      // Sit 8 dp above the bottom nav (≈56 dp) + system bottom inset
      final bottomOffset = mq.padding.bottom + 56 + 8;

      // KEY FIX: wrap everything in a full-screen non-absorbing Stack
      // with a transparent background so only the card itself is visible
      // and touchable — the rest of the screen remains fully interactive.
      return Positioned.fill(
        child: IgnorePointer(
          // Allow touches everywhere EXCEPT inside the banner card itself.
          // We re-enable pointer events only on the card via a nested
          // IgnorePointer(ignoring: false) implicitly (default is false).
          ignoring: false,
          child: Stack(
            children: [
              // Transparent full-screen backdrop — passes all touches through
              const Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: SizedBox.expand(),
                ),
              ),
              // The actual banner card, anchored to the bottom
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
                  onViewMap: () {
                    _dismiss(entry);
                    onViewMap();
                  },
                  onEvacuate: () {
                    _dismiss(entry);
                    onEvacuate();
                  },
                  onDismiss: () => _dismiss(entry),
                ),
              ),
            ],
          ),
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

// ── Animated banner widget ────────────────────────────────────────────────────
class _CriticalBanner extends StatefulWidget {
  final String   stationName;
  final String   riverName;
  final double   currentLevel;
  final double   dangerLevel;
  final String   district;
  final VoidCallback onViewMap;
  final VoidCallback onEvacuate;
  final VoidCallback onDismiss;

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<Offset>    _slide;
  Timer? _autoTimer;

  static const _autoDismiss = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // Slide UP from below: begin Offset(0,1) means 100% below own height
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    _anim.forward();

    _autoTimer = Timer(_autoDismiss, () {
      if (mounted) _animatedDismiss();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _animatedDismiss() {
    _autoTimer?.cancel();
    _anim.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 200) _animatedDismiss();
      },
      // ClipRect is critical: prevents the card painting OUTSIDE its
      // Positioned bounds during the slide-in animation, which was what
      // caused the full-screen red flash in v3.0.
      child: ClipRect(
        child: SlideTransition(
          position: _slide,
          child: _BannerCard(
            stationName:  widget.stationName,
            riverName:    widget.riverName,
            currentLevel: widget.currentLevel,
            dangerLevel:  widget.dangerLevel,
            district:     widget.district,
            onViewMap:    widget.onViewMap,
            onEvacuate:   widget.onEvacuate,
            onDismiss:    _animatedDismiss,
          ),
        ),
      ),
    );
  }
}

// ── Visual card ───────────────────────────────────────────────────────────────
// Uses Container + BoxDecoration (NOT Material) so the dark-red background
// is scoped to the card's intrinsic height — no full-height background flash.
class _BannerCard extends StatelessWidget {
  final String   stationName;
  final String   riverName;
  final double   currentLevel;
  final double   dangerLevel;
  final String   district;
  final VoidCallback onViewMap;
  final VoidCallback onEvacuate;
  final VoidCallback onDismiss;

  const _BannerCard({
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
  Widget build(BuildContext context) {
    const danger  = Color(0xFFFF1744);
    const warning = Color(0xFFFF6D00);
    final aboveDl = currentLevel - dangerLevel;
    final isAbove = aboveDl >= 0;
    final accent  = isAbove ? danger : warning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        // No Material() here — scoped container only, no implicit full-height bg
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A0A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.8), width: 1.5),
          gradient: LinearGradient(
            colors: [accent.withOpacity(0.18), const Color(0xFF1A0A0A)],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color:      accent.withOpacity(0.30),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header row ──────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: accent.withOpacity(0.6), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_rounded,
                            color: accent, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          isAbove ? 'CRITICAL' : 'DANGER',
                          style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stationName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: onDismiss,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white54, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ── River · district ────────────────────────────────────────
              Text(
                '$riverName  ·  ${district.isNotEmpty ? district : "Bihar"}',
                style: const TextStyle(
                    color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 4),
              // ── Level line ──────────────────────────────────────────────
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12),
                  children: [
                    TextSpan(
                      text: '${currentLevel.toStringAsFixed(2)} m  ',
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: isAbove
                          ? '(+${aboveDl.toStringAsFixed(2)} m above DL '
                              '${dangerLevel.toStringAsFixed(2)} m)'
                          : '(DL ${dangerLevel.toStringAsFixed(2)} m)',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // ── Action row ──────────────────────────────────────────────
              Row(
                children: [
                  _ActionBtn(
                    label: 'View Map',
                    icon:  Icons.map_outlined,
                    color: const Color(0xFF00B0FF),
                    onTap: onViewMap,
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    label: 'Evacuate',
                    icon:  Icons.directions_run_rounded,
                    color: danger,
                    onTap: onEvacuate,
                  ),
                  const Spacer(),
                  const Text(
                    'Swipe ↓ to dismiss',
                    style: TextStyle(
                        color: Colors.white30, fontSize: 9),
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

class _ActionBtn extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final Color      color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
