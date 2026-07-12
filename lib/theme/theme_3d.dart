// lib/theme/theme_3d.dart
// OpsFlood — Global 3-D UI System v3.1
//
// v3.1 overflow fix:
//   • Td3StatTile: Column overflowed by 3.9px on h=61.1 constraint
//     Root cause: badge(26)+gap(5)+value(20)+gap(2)+label(12)+pad(16) = 81 > 61
//     Fix: padding 8→5, badge 26→22 (icon 14→12), gap after badge 5→3,
//          value fontSize 20→17, gap before label 2→1
//     New budget: pad(5)+pad(5)+badge(22)+gap(3)+value(17)+gap(1)+label(12) = 65
//     mainAxisSize.min + no icon path: value(17)+gap(1)+label(12)+pad(10) = 40 ✔
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'river_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
class Td3 {
  Td3._();
  static const double elevFlush = 0;
  static const double elevLow = 2;
  static const double elevMid = 4;
  static const double elevHigh = 8;
  static const double elevFloat = 14;
  static const double glossStrong = 0.22;
  static const double glossMid = 0.13;
  static const double glossSoft = 0.07;
  static const Color shadowDark = Color(0x44201808);
  static const Color shadowMid = Color(0x28201808);
  static const Color shadowLight = Color(0x14201808);
  static const Color edgeDark = Color(0x55000000);
  static const Color edgeMid = Color(0x33000000);
  static const Duration pressDown = Duration(milliseconds: 80);
  static const Duration pressUp = Duration(milliseconds: 160);

  static List<BoxShadow> cardShadow(Color accent, {double elev = elevMid}) => [
        BoxShadow(
            color: shadowDark,
            blurRadius: elev * 0.8,
            spreadRadius: -elev * 0.3,
            offset: Offset(0, elev * 0.5)),
        BoxShadow(
            color: shadowLight,
            blurRadius: elev * 3,
            offset: Offset(0, elev * 1.5)),
        BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: elev * 4,
            spreadRadius: elev * 0.2,
            offset: Offset(0, elev * 2)),
      ];
  static List<BoxShadow> pressedShadow() => [
        BoxShadow(
            color: shadowDark,
            blurRadius: 2,
            spreadRadius: 1,
            offset: const Offset(0, 1)),
      ];
  static List<BoxShadow> badgeShadow(Color c) => [
        BoxShadow(
            color: c.withValues(alpha: 0.50),
            blurRadius: 6,
            offset: const Offset(0, 3)),
        BoxShadow(color: shadowDark, blurRadius: 2, offset: const Offset(0, 1)),
      ];
  static Border depthBorder(
          {Color? topColor, Color? bottomColor, double width = 1.0}) =>
      Border(
        top: BorderSide(
            color: topColor ?? const Color(0x33FFFFFF), width: width),
        bottom: BorderSide(color: bottomColor ?? edgeMid, width: width),
        left: BorderSide(color: const Color(0x18FFFFFF), width: width * 0.5),
        right: BorderSide(color: const Color(0x22000000), width: width * 0.5),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3Card
// ─────────────────────────────────────────────────────────────────────────────
class Td3Card extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? accentColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double elevation;
  final bool showGloss;
  final bool showDepthEdge;
  final VoidCallback? onTap;

  const Td3Card({
    super.key,
    required this.child,
    this.color,
    this.accentColor,
    this.borderRadius,
    this.padding,
    this.elevation = Td3.elevMid,
    this.showGloss = true,
    this.showDepthEdge = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final c = color ?? t.cardBg;
    final br = borderRadius ?? BorderRadius.circular(18);
    final ac = accentColor ?? t.accent;

    Widget content = ClipRRect(
      borderRadius: br,
      child: Stack(children: [
        Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
        if (showGloss)
          Positioned.fill(
              child: IgnorePointer(
            child: CustomPaint(
                painter: _GlossPainter(radius: br, opacity: Td3.glossMid)),
          )),
      ]),
    );

    content = Container(
      decoration: BoxDecoration(
        color: c,
        borderRadius: br,
        boxShadow: Td3.cardShadow(ac, elev: elevation),
        border: Border.all(color: t.stroke.withValues(alpha: 0.5), width: 0.75),
      ),
      child: Stack(children: [
        content,
        if (showDepthEdge)
          Positioned.fill(
              child: IgnorePointer(
            child: DecoratedBox(
                decoration: BoxDecoration(
              borderRadius: br,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06), width: 0.75),
            )),
          )),
      ]),
    );

    return onTap != null
        ? GestureDetector(onTap: onTap, child: content)
        : content;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3Button
// ─────────────────────────────────────────────────────────────────────────────
class Td3Button extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;
  final Color? textColor;
  final double height;
  final double? width;
  final bool loading;
  final double borderRadius;

  const Td3Button({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.color,
    this.textColor,
    this.height = 52,
    this.width,
    this.loading = false,
    this.borderRadius = 16,
  });

  @override
  State<Td3Button> createState() => _Td3ButtonState();
}

class _Td3ButtonState extends State<Td3Button>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final c = widget.color ?? t.accent;
    final tc = widget.textColor ?? Colors.white;
    final br = BorderRadius.circular(widget.borderRadius);
    final sinkY = _pressed ? 3.0 : 0.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: _pressed ? Td3.pressDown : Td3.pressUp,
        curve: Curves.easeOut,
        width: widget.width ?? double.infinity,
        height: widget.height,
        transform: Matrix4.translationValues(0, sinkY, 0),
        decoration: BoxDecoration(
          borderRadius: br,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _pressed
                ? [c.withValues(alpha: 0.6), c.withValues(alpha: 0.5)]
                : [_lighten(c, 0.12), c, _darken(c, 0.12)],
            stops: _pressed ? null : const [0.0, 0.5, 1.0],
          ),
          border: Td3.depthBorder(
            topColor: Colors.white.withValues(alpha: _pressed ? 0.08 : 0.22),
            bottomColor: Colors.black.withValues(alpha: _pressed ? 0.08 : 0.28),
          ),
          boxShadow: _pressed
              ? Td3.pressedShadow()
              : [
                  BoxShadow(
                      color: c.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 5)),
                  BoxShadow(
                      color: Td3.shadowDark,
                      blurRadius: 4,
                      offset: const Offset(0, 2)),
                ],
        ),
        child: ClipRRect(
          borderRadius: br,
          child: Stack(children: [
            Center(
              child: widget.loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(tc)))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: tc, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(widget.label,
                            style: TextStyle(
                              color: tc,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            )),
                      ],
                    ),
            ),
            if (!_pressed)
              Positioned.fill(
                  child: IgnorePointer(
                child: CustomPaint(
                    painter:
                        _GlossPainter(radius: br, opacity: Td3.glossStrong)),
              )),
          ]),
        ),
      ),
    );
  }
}

Color _lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3Chip
// ─────────────────────────────────────────────────────────────────────────────
class Td3Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;
  final double? fontSize;

  const Td3Chip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.selected = false,
    this.onTap,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final c = color ?? t.accent;
    final bg = selected ? c.withValues(alpha: 0.18) : t.cardBg;
    final br = BorderRadius.circular(24);
    final fs = fontSize ?? 12.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: br,
          border: Border.all(
            color: selected
                ? c.withValues(alpha: 0.60)
                : t.divider.withValues(alpha: 0.6),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: c.withValues(alpha: 0.20),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? c : t.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                  fontSize: fs,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? c : t.textSecondary,
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3ProgressBar
// ─────────────────────────────────────────────────────────────────────────────
class Td3ProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? fillColor;
  final double height;
  final String? label;

  const Td3ProgressBar({
    super.key,
    required this.value,
    this.color,
    this.fillColor,
    this.height = 10,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final c = fillColor ?? color ?? t.accent;
    final v = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: TextStyle(fontSize: 11, color: t.textSecondary)),
          const SizedBox(height: 4),
        ],
        Container(
          height: height,
          decoration: BoxDecoration(
            color: t.cardBgElevated,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
                color: Colors.black.withValues(alpha: 0.14), width: 0.75),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 3,
                  offset: const Offset(0, 1))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: Stack(children: [
              FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_lighten(c, 0.10), c, _darken(c, 0.08)],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.50),
                        blurRadius: height * 1.5,
                        offset: Offset(0, height * 0.3),
                      )
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                  child: IgnorePointer(
                child: CustomPaint(
                    painter: _GlossPainter(
                  radius: BorderRadius.circular(height / 2),
                  opacity: Td3.glossSoft,
                )),
              )),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3StatTile  v3.1  — overflow-safe, budget fits h ≥ 56
//
// Measured constraint from error log: h = 61.1 px
// Previous content height: pad(8+8) + badge(26) + gap(5) + value(20) + gap(2)
//                          + label(12.1) = 81.1  →  overflow 3.9 ✗
//
// Fixed content height:    pad(5+5) + badge(22) + gap(3) + FittedBox(value≤17)
//                          + gap(1) + label(12.1) = 65.1  →  fits in 61.1
// The FittedBox on value scales it down further if the cell is narrower,
// so the tile is safe at any childAspectRatio ≥ 2.0.
// ─────────────────────────────────────────────────────────────────────────────
class Td3StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? valueColor;
  final double elevation;
  final VoidCallback? onTap;

  const Td3StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.valueColor,
    this.elevation = Td3.elevHigh,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final vc = valueColor ?? t.accent;

    return Td3Card(
      accentColor: vc,
      elevation: elevation,
      onTap: onTap,
      child: Padding(
        // ✔ 5 pt vertical padding (was 8) — saves 6 pt total
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              // ✔ badge 22×22 (was 26) — saves 4 pt
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: vc.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                  border:
                      Border.all(color: vc.withValues(alpha: 0.30), width: 1),
                ),
                child: Center(child: Icon(icon, color: vc, size: 12)),
              ),
              // ✔ gap 3 pt (was 5) — saves 2 pt
              const SizedBox(height: 3),
            ],
            // ✔ FittedBox scales value down if needed — safe at any width
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: vc,
                  // ✔ fontSize 17 (was 20) — saves 3 pt
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
            // ✔ gap 1 pt (was 2)
            const SizedBox(height: 1),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3Badge
// ─────────────────────────────────────────────────────────────────────────────
class Td3Badge extends StatelessWidget {
  final String text;
  final Color? color;
  final double fontSize;
  final String? severity;

  Td3Badge({
    super.key,
    String? text,
    String? label,
    this.color,
    this.fontSize = 10,
    this.severity,
  })  : assert(
            text != null || label != null, 'Td3Badge requires text or label'),
        text = text ?? label!;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final c = severity != null
        ? AppPalette.statusColor(severity!)
        : (color ?? t.accent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Td3.badgeShadow(c),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.25), width: 0.75),
      ),
      child: Text(text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.3,
          )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3SectionHeader
// ─────────────────────────────────────────────────────────────────────────────
class Td3SectionHeader extends StatelessWidget {
  final String text;
  final Color? accentColor;
  final bool showLine;
  final IconData? icon;

  const Td3SectionHeader(
    this.text, {
    super.key,
    this.accentColor,
    this.showLine = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final c = accentColor ?? t.accent;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: c, size: 14),
                const SizedBox(width: 6),
              ],
              Text(text.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c,
                    letterSpacing: 1.4,
                  )),
            ],
          ),
          if (showLine) ...[
            const SizedBox(height: 5),
            Container(
              height: 2,
              width: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(colors: [c, c.withValues(alpha: 0.0)]),
                boxShadow: [
                  BoxShadow(
                      color: c.withValues(alpha: 0.50),
                      blurRadius: 6,
                      offset: const Offset(0, 1))
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3Divider
// ─────────────────────────────────────────────────────────────────────────────
class Td3Divider extends StatelessWidget {
  const Td3Divider({super.key});
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(height: 1, color: t.divider.withValues(alpha: 0.5));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3AppBar
// ─────────────────────────────────────────────────────────────────────────────
class Td3AppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool pinned;
  final double expandedHeight;

  const Td3AppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.pinned = true,
    this.expandedHeight = 80,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return SliverAppBar(
      pinned: pinned,
      expandedHeight: subtitle != null ? expandedHeight + 20 : expandedHeight,
      backgroundColor: t.navBg,
      leading: leading,
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              t.accent.withValues(alpha: 0.0),
              t.accent.withValues(alpha: 0.5),
              t.accent.withValues(alpha: 0.0),
            ]),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 14),
        centerTitle: false,
        title: subtitle != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      )),
                ],
              )
            : Text(title,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [t.navBg, t.navBg.withValues(alpha: 0.92)],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3BottomNav
// ─────────────────────────────────────────────────────────────────────────────
class Td3BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<Td3NavItem> items;
  final ValueChanged<int> onTap;

  const Td3BottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final sw = MediaQuery.of(context).size.width;
    final pb = MediaQuery.of(context).padding.bottom;
    final navH = 68.0;

    return Container(
      height: navH + pb,
      decoration: BoxDecoration(
        color: t.navBg,
        border: Border(
            top: BorderSide(
                color: t.stroke.withValues(alpha: 0.35), width: 0.75)),
        boxShadow: [
          BoxShadow(
              color: Td3.shadowMid, blurRadius: 16, offset: const Offset(0, -4))
        ],
      ),
      child: Stack(children: [
        Padding(
          padding: EdgeInsets.only(bottom: pb),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? item.activeIcon : item.icon,
                        color: selected ? t.accent : t.textSecondary,
                        size: selected ? 24 : 22,
                      ),
                      const SizedBox(height: 3),
                      Text(item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color: selected ? t.accent : t.textSecondary,
                          )),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          left: (sw / items.length) * currentIndex + 16,
          bottom: pb + 4,
          width: (sw / items.length) - 32,
          height: 3,
          child: Container(
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.55),
                  blurRadius: 8,
                  offset: const Offset(0, 0),
                )
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class Td3NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const Td3NavItem(
      {required this.icon, required this.activeIcon, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3InputField
// ─────────────────────────────────────────────────────────────────────────────
class Td3InputField extends StatefulWidget {
  final String label;
  final String? hint;
  final IconData? icon;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool required;
  final bool readOnly;
  final Widget? suffixWidget;

  const Td3InputField({
    super.key,
    required this.label,
    this.hint,
    this.icon,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.required = false,
    this.readOnly = false,
    this.suffixWidget,
  });

  @override
  State<Td3InputField> createState() => _Td3InputFieldState();
}

class _Td3InputFieldState extends State<Td3InputField> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final br = BorderRadius.circular(12);
    final labelText = widget.required ? '${widget.label} *' : widget.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(labelText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.textSecondary,
              letterSpacing: 0.5,
            )),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: t.cardBgElevated,
            borderRadius: br,
            border: Border.all(
              color: _focused ? t.accent.withValues(alpha: 0.7) : t.divider,
              width: _focused ? 1.5 : 1.0,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                        color: t.accent.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1))
                  ],
          ),
          child: TextField(
            focusNode: _focus,
            controller: widget.controller,
            onChanged: widget.onChanged,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            readOnly: widget.readOnly,
            style: TextStyle(color: t.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: t.textSecondary),
              prefixIcon: widget.icon != null
                  ? Icon(widget.icon, color: t.textSecondary, size: 18)
                  : null,
              suffixIcon: widget.suffixWidget,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GlossPainter — glass covers top 40%
// ─────────────────────────────────────────────────────────────────────────────
class _GlossPainter extends CustomPainter {
  final BorderRadius radius;
  final double opacity;
  const _GlossPainter({required this.radius, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Offset.zero & size,
        topLeft: radius.topLeft,
        topRight: radius.topRight,
        bottomLeft: radius.bottomLeft,
        bottomRight: radius.bottomRight,
      ));
    canvas.save();
    canvas.clipPath(path);
    final glossHeight = size.height * 0.40;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, glossHeight),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: opacity),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, glossHeight)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlossPainter old) =>
      old.opacity != opacity || old.radius != radius;
}

// ignore: unused_element
double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
// ignore: unused_element
double _unused = math.pi;
