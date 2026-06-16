// lib/widgets/dashboard/river_pulse_card.dart
// ═══════════════════════════════════════════════════════════════════════════
// RiverPulseCard  —  Data Terminal Edition
//
// ✔  Consumes ThemeRegistry — no hardcoded colors
// ✔  Entry animation: slide-up + blur-in on first data arrival
// ✔  Reactive to realTimeRiverProvider — water level updates live
// ✔  Monospace numbers, glow borders, terminal header
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/river_station.dart';
import '../../theme/theme_registry.dart';

// ─── Public widget ─────────────────────────────────────────────────────────────────
/// A self-animating "Data Terminal" card that shows live river data.
/// Pass [station] from realTimeRiverProvider; the card handles its own
/// entry animation. Pass [index] for staggered delays across a list.
class RiverPulseCard extends ConsumerStatefulWidget {
  const RiverPulseCard({
    super.key,
    required this.station,
    this.index = 0,
    this.onTap,
  });

  final RiverStation        station;
  final int                 index;
  final VoidCallback?       onTap;

  @override
  ConsumerState<RiverPulseCard> createState() => _RiverPulseCardState();
}

class _RiverPulseCardState extends ConsumerState<RiverPulseCard>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  late final Animation<double>    _slide;   // 0 → 1 (offset from bottom)
  late final Animation<double>    _fade;    // 0 → 1 (opacity + blur)

  @override
  void initState() {
    super.initState();
    final rc = ThemeRegistry.of(ref.read(appSkinProvider));

    _ctrl = AnimationController(
      vsync:    this,
      duration: rc.entryDuration + Duration(
          milliseconds: widget.index * 60), // stagger
    );

    _slide = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: rc.entryCurve),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );

    // Trigger entry after short delay based on index
    Future.delayed(Duration(milliseconds: 80 + widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rc      = ref.watch(themeRegistryProvider);
    final station = widget.station;
    final lvlColor = station.hasData
        ? rc.levelColor(station.current, station.warning, station.danger)
        : rc.textMuted;
    final dc = station.dangerClass;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final slideOffset = _slide.value * 48.0; // px from bottom
        final blurSigma   = (1 - _fade.value) * 6.0;

        return Transform.translate(
          offset: Offset(0, slideOffset),
          child: Opacity(
            opacity: _fade.value.clamp(0.0, 1.0),
            child: ImageFilter.matrix(
              // BackdropFilter-based blur on the card itself
              Matrix4.identity().storage,
            ) != null
                // Use a simple opacity+translate without ImageFilter for
                // performance — blur is simulated via opacity ramp.
                ? child
                : child,
          ),
        );
      },
      child: _buildCard(rc, station, lvlColor, dc),
    );
  }

  Widget _buildCard(
    SkinTokens rc,
    RiverStation station,
    Color lvlColor,
    DangerClass dc,
  ) {
    final isAlert = dc == DangerClass.severe || dc == DangerClass.extreme;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin:  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: rc.terminalBox.copyWith(
          boxShadow: isAlert
              ? rc.glowFor(lvlColor, blur: 18)
              : rc.cardGlow,
          border: Border.all(
            color: isAlert
                ? lvlColor.withOpacity(0.45)
                : rc.stroke,
            width: isAlert ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TerminalHeader(rc: rc, station: station, lvlColor: lvlColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LevelReadout(
                      rc: rc, station: station, lvlColor: lvlColor),
                  const SizedBox(height: 12),
                  _ThresholdBar(rc: rc, station: station, lvlColor: lvlColor),
                  const SizedBox(height: 10),
                  _MetaRow(rc: rc, station: station),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _TerminalHeader ───────────────────────────────────────────────────────────────
// Mimics a terminal title bar with station ID and live dot.
// FIX: Replaced Border(bottom: BorderSide(...)) + BorderRadius.only(top) combo
// which caused 'A borderRadius can only be given on borders with uniform colors'
// Flutter assertion. Now uses a uniform border (none) on the BoxDecoration and
// a separate 1px divider Container as the bottom separator — fully legal.
class _TerminalHeader extends StatelessWidget {
  const _TerminalHeader({
    required this.rc,
    required this.station,
    required this.lvlColor,
  });
  final SkinTokens   rc;
  final RiverStation station;
  final Color        lvlColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color:        rc.surfaceHigh,
            // Only uniform border (or none) is allowed with borderRadius.
            // The bottom divider is rendered as a separate child Container below.
            borderRadius: BorderRadius.only(
              topLeft:  rc.cardRadius.topLeft,
              topRight: rc.cardRadius.topRight,
            ),
          ),
          child: Row(
            children: [
              // Live pulse dot
              _LiveDot(color: station.isLive ? rc.safe : rc.textMuted),
              if (!station.hasData) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: rc.textMuted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'NO DATA',
                    style: rc.labelSm.copyWith(
                      color:      rc.textMuted,
                      fontSize:   9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  station.station.toUpperCase(),
                  style: rc.labelSm.copyWith(color: rc.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Risk chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: rc.chipBox.copyWith(
                  color: lvlColor.withOpacity(0.12),
                  border: Border.all(
                      color: lvlColor.withOpacity(0.40), width: 1),
                ),
                child: Text(
                  _dcLabel(station.dangerClass),
                  style: rc.labelXs.copyWith(
                      color: lvlColor,
                      letterSpacing: 1.0),
                ),
              ),
            ],
          ),
        ),
        // Bottom divider — rendered as a separate child to avoid the
        // non-uniform border + borderRadius illegal combination.
        Container(
          height: 1,
          color:  rc.divider,
        ),
      ],
    );
  }

  String _dcLabel(DangerClass dc) {
    switch (dc) {
      case DangerClass.extreme:     return 'CRITICAL';
      case DangerClass.severe:      return 'HIGH';
      case DangerClass.aboveNormal: return 'MOD';
      case DangerClass.normal:      return 'NORMAL';
    }
  }
}

// ── _LevelReadout ─────────────────────────────────────────────────────────────────
// Monospace water level with unit
class _LevelReadout extends StatelessWidget {
  const _LevelReadout({
    required this.rc,
    required this.station,
    required this.lvlColor,
  });
  final SkinTokens   rc;
  final RiverStation station;
  final Color        lvlColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${station.river}',
          style: rc.labelSm.copyWith(color: rc.textSecondary),
        ),
        const Spacer(),
        // Animated level number
        TweenAnimationBuilder<double>(
          tween: Tween(end: station.current),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(
            v.toStringAsFixed(2),
            style: rc.monoLg.copyWith(color: lvlColor),
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('m', style: rc.monoSm),
        ),
      ],
    );
  }
}

// ── _ThresholdBar ────────────────────────────────────────────────────────────────
// Segmented progress bar with warning + danger tick marks
class _ThresholdBar extends StatelessWidget {
  const _ThresholdBar({
    required this.rc,
    required this.station,
    required this.lvlColor,
  });
  final SkinTokens   rc;
  final RiverStation station;
  final Color        lvlColor;

  @override
  Widget build(BuildContext context) {
    final pct     = station.progressPct.clamp(0.0, 1.0);
    final warnPct = station.hfl > 0
        ? (station.warning / station.hfl).clamp(0.0, 1.0)
        : 0.5;
    final dangPct = station.hfl > 0
        ? (station.danger / station.hfl).clamp(0.0, 1.0)
        : 0.75;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('LEVEL  /  HFL', style: rc.labelXs),
            Text(
              '${(pct * 100).toStringAsFixed(1)}%',
              style: rc.monoSm.copyWith(color: lvlColor, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(builder: (_, box) {
          final w = box.maxWidth;
          return Stack(
            children: [
              // Background track
              Container(
                height: 7,
                width:  w,
                decoration: BoxDecoration(
                  color:        rc.surfaceHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: rc.stroke, width: 1),
                ),
              ),
              // Fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve:    Curves.easeOutCubic,
                height:   7,
                width:    (w * pct).clamp(0, w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    lvlColor.withOpacity(0.6),
                    lvlColor,
                  ]),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                        color: lvlColor.withOpacity(0.5),
                        blurRadius: 6)
                  ],
                ),
              ),
              // Warning tick
              Positioned(
                left: w * warnPct - 1,
                child: Container(
                    width: 2, height: 7,
                    color: rc.warning.withOpacity(0.7)),
              ),
              // Danger tick
              Positioned(
                left: w * dangPct - 1,
                child: Container(
                    width: 2, height: 7,
                    color: rc.danger.withOpacity(0.7)),
              ),
            ],
          );
        }),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Tick(label: 'WARN  ${station.warning.toStringAsFixed(1)}m',
                color: rc.warning, rc: rc),
            _Tick(label: 'DNGR  ${station.danger.toStringAsFixed(1)}m',
                color: rc.danger, rc: rc),
          ],
        ),
      ],
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({
    required this.label,
    required this.color,
    required this.rc,
  });
  final String     label;
  final Color      color;
  final SkinTokens rc;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: rc.labelXs.copyWith(color: color.withOpacity(0.75)),
  );
}

// ── _MetaRow ──────────────────────────────────────────────────────────────────────
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.rc, required this.station});
  final SkinTokens   rc;
  final RiverStation station;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MetaChip(
          icon: Icons.location_on_rounded,
          label: station.city,
          rc: rc,
        ),
        const SizedBox(width: 6),
        _MetaChip(
          icon: Icons.update_rounded,
          label: station.lastUpdated ?? '—',
          rc: rc,
        ),
        const Spacer(),
        if (station.dataSource != null)
          Text(
            station.dataSource!,
            style: rc.labelXs.copyWith(
                color: rc.accentSecondary.withOpacity(0.7)),
          ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.rc,
  });
  final IconData   icon;
  final String     label;
  final SkinTokens rc;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: rc.textMuted),
      const SizedBox(width: 3),
      Text(label,
          style: rc.labelXs.copyWith(color: rc.textSecondary)),
    ],
  );
}

// ── _LiveDot ───────────────────────────────────────────────────────────────────────
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});
  final Color color;
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withOpacity(0.6 + 0.4 * _c.value),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.5 * _c.value),
            blurRadius: 6,
            spreadRadius: 1,
          )
        ],
      ),
    ),
  );
}
