// lib/theme/theme_3d.dart
// OpsFlood — Global 3-D UI System v1
//
// Provides:
//   • Td3Card          — any card with depth shadow + specular highlight
//   • Td3Button        — press-to-sink 3-D button
//   • Td3Chip          — pill chip with emboss
//   • Td3ProgressBar   — layered depth progress track
//   • Td3StatTile      — KPI tile with raised number + depth glow
//   • Td3Badge         — floating badge with hard drop-shadow
//   • Td3AppBar        — SliverAppBar with layered bottom edge
//   • Td3BottomNav     — BottomNavBar with floating pill indicator
//   • Td3InputField    — recessed 3-D input (added onChanged in v1.1)
//   • Td3Painters      — CustomPainter helpers (gloss overlay, depth edge)
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'river_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design constants
// ─────────────────────────────────────────────────────────────────────────────

class Td3 {
  Td3._();

  static const double elevFlush   = 0;
  static const double elevLow     = 2;
  static const double elevMid     = 4;
  static const double elevHigh    = 8;
  static const double elevFloat   = 14;

  static const double glossStrong = 0.22;
  static const double glossMid    = 0.13;
  static const double glossSoft   = 0.07;

  static const Color shadowDark   = Color(0x44201808);
  static const Color shadowMid    = Color(0x28201808);
  static const Color shadowLight  = Color(0x14201808);

  static const Color edgeDark     = Color(0x55000000);
  static const Color edgeMid      = Color(0x33000000);

  static const Duration pressDown = Duration(milliseconds: 80);
  static const Duration pressUp   = Duration(milliseconds: 160);

  static List<BoxShadow> cardShadow(Color accent, {double elev = elevMid}) =>
      [
        BoxShadow(
          color: shadowDark,
          blurRadius: elev * 0.8,
          spreadRadius: -elev * 0.3,
          offset: Offset(0, elev * 0.5),
        ),
        BoxShadow(
          color: shadowLight,
          blurRadius: elev * 3,
          spreadRadius: 0,
          offset: Offset(0, elev * 1.5),
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.08),
          blurRadius: elev * 4,
          spreadRadius: elev * 0.2,
          offset: Offset(0, elev * 2),
        ),
      ];

  static List<BoxShadow> pressedShadow() => [
        BoxShadow(
          color: shadowDark,
          blurRadius: 2,
          spreadRadius: 1,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> badgeShadow(Color c) => [
        BoxShadow(
            color: c.withValues(alpha: 0.50),
            blurRadius: 6,
            offset: const Offset(0, 3)),
        BoxShadow(
            color: shadowDark,
            blurRadius: 2,
            offset: const Offset(0, 1)),
      ];

  static Border depthBorder({
    Color? topColor,
    Color? bottomColor,
    double width = 1.0,
  }) =>
      Border(
        top: BorderSide(
          color: topColor ?? const Color(0x33FFFFFF),
          width: width,
        ),
        bottom: BorderSide(
          color: bottomColor ?? edgeMid,
          width: width,
        ),
        left: BorderSide(
          color: const Color(0x18FFFFFF),
          width: width * 0.5,
        ),
        right: BorderSide(
          color: edgeDark.withAlpha(0x22),
          width: width * 0.5,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3Card
// ─────────────────────────────────────────────────────────────────────────────

class Td3Card extends StatelessWidget {
  final Widget   child;
  final Color?   color;
  final Color?   accentColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double   elevation;
  final bool     showGloss;
  final bool     showDepthEdge;
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
    final t  = RiverColors.of(context);
    final c  = color ?? t.cardBg;
    final br = borderRadius ?? BorderRadius.circular(16);
    final ac = accentColor ?? t.accent;

    Widget content = ClipRRect(
      borderRadius: br,
      child: Stack(
        children: [
          Padding(
            padding: padding ?? const EdgeInsets.all(0),
            child: child,
          ),
          if (showGloss)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GlossPainter(radius: br, opacity: Td3.glossMid),
                ),
              ),
            ),
        ],
      ),
    );

    content = Container(
      decoration: BoxDecoration(
        color: c,
        borderRadius: br,
        border: Td3.depthBorder(),
        boxShadow: Td3.cardShadow(ac, elev: elevation),
      ),
      child: content,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3Button
// ─────────────────────────────────────────────────────────────────────────────

class Td3Button extends StatefulWidget {
  final String  label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color?  color;
  final Color?  textColor;
  final double  height;
  final double? width;
  final bool    loading;
  final double  borderRadius;

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
    final t  = RiverColors.of(context);
    final c  = widget.color ?? t.accent;
    final tc = widget.textColor ?? Colors.white;
    final br = BorderRadius.circular(widget.borderRadius);

    final sinkY = _pressed ? 3.0 : 0.0;

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: _pressed ? Td3.pressDown : Td3.pressUp,
        curve: Curves.easeOut,
        width:  widget.width ?? double.infinity,
        height: widget.height,
        transform: Matrix4.translationValues(0, sinkY, 0),
        decoration: BoxDecoration(
          borderRadius: br,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: _pressed
                ? [c.withValues(alpha: 0.6), c.withValues(alpha: 0.5)]
                : [
                    _lighten(c, 0.12),
                    c,
                    _darken(c, 0.12),
                  ],
            stops: _pressed ? null : const [0.0, 0.5, 1.0],
          ),
          border: Td3.depthBorder(
            topColor:    Colors.white.withValues(alpha: _pressed ? 0.08 : 0.22),
            bottomColor: Colors.black.withValues(alpha: _pressed ? 0.08 : 0.28),
          ),
          boxShadow: _pressed
              ? Td3.pressedShadow()
              : [
                  BoxShadow(
                    color: c.withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 0,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Td3.shadowDark,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: br,
          child: Stack(
            children: [
              Center(
                child: widget.loading
                    ? SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: tc),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: tc, size: 18),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: tc,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GlossPainter(
                      radius: br,
                      opacity: _pressed ? 0.04 : Td3.glossStrong,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3Chip
// ─────────────────────────────────────────────────────────────────────────────

class Td3Chip extends StatelessWidget {
  final String  label;
  final Color   color;
  final Color?  textColor;
  final IconData? icon;
  final double  fontSize;

  const Td3Chip({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
    this.icon,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final tc = textColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [_lighten(color, 0.10), color, _darken(color, 0.08)],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.18), width: 0.8),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.40),
              blurRadius: 6,
              offset: const Offset(0, 2)),
          BoxShadow(
              color: Td3.shadowDark,
              blurRadius: 2,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: tc, size: fontSize + 2),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: tc,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3ProgressBar
// ─────────────────────────────────────────────────────────────────────────────

class Td3ProgressBar extends StatelessWidget {
  final double value;
  final Color  fillColor;
  final double height;
  final BorderRadius? borderRadius;

  const Td3ProgressBar({
    super.key,
    required this.value,
    required this.fillColor,
    this.height = 10,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final t  = RiverColors.of(context);
    final br = borderRadius ?? BorderRadius.circular(height / 2);
    final v  = value.clamp(0.0, 1.0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: br,
        color: t.stroke.withValues(alpha: 0.25),
        border: Border.all(
            color: Td3.shadowDark, width: 0.6),
        boxShadow: [
          BoxShadow(
              color: Td3.shadowDark,
              blurRadius: 3,
              spreadRadius: -1),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end:   Alignment.bottomCenter,
                    colors: [
                      _lighten(fillColor, 0.18),
                      fillColor,
                      _darken(fillColor, 0.15),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0, left: 0, right: 0,
              height: height * 0.38,
              child: FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end:   Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.35),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Td3StatTile
// ─────────────────────────────────────────────────────────────────────────────

class Td3StatTile extends StatelessWidget {
  final String   value;
  final String   label;
  final Color    valueColor;
  final IconData? icon;
  final VoidCallback? onTap;

  const Td3StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.valueColor,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Td3Card(
      accentColor: valueColor,
      elevation: Td3.elevHigh,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: valueColor, size: 18),
              const SizedBox(height: 8),
            ],
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                shadows: [
                  Shadow(
                      color: valueColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                  Shadow(
                      color: Td3.shadowDark,
                      blurRadius: 3,
                      offset: const Offset(0, 1)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
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
  final String  label;
  final Color   color;
  final IconData? icon;
  final double  fontSize;

  const Td3Badge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.fontSize = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
            color: color.withValues(alpha: 0.45), width: 1.0),
        boxShadow: Td3.badgeShadow(color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: fontSize + 2),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3AppBar
// ─────────────────────────────────────────────────────────────────────────────

class Td3AppBar extends StatelessWidget {
  final String    title;
  final String?   subtitle;
  final List<Widget> actions;
  final Widget?   leading;
  final bool      pinned;
  final double    expandedHeight;

  const Td3AppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.pinned = true,
    this.expandedHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return SliverAppBar(
      pinned:         pinned,
      expandedHeight: expandedHeight > 0 ? expandedHeight : null,
      backgroundColor: t.scaffoldBg,
      elevation: 0,
      leading: leading,
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.5),
        child: Container(
          height: 1.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Td3.edgeDark.withAlpha(0x00),
                Td3.edgeMid,
                Td3.edgeDark.withAlpha(0x00),
              ],
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end:   Alignment.bottomCenter,
              colors: [
                t.scaffoldBg,
                t.cardBg,
              ],
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

class Td3NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  const Td3NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class Td3BottomNav extends StatelessWidget {
  final List<Td3NavItem> items;
  final int              currentIndex;
  final ValueChanged<int> onTap;

  const Td3BottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        border: Border(
          top: BorderSide(color: t.stroke.withValues(alpha: 0.5), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
              color: Td3.shadowDark,
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: List.generate(items.length, (i) {
              final item     = items[i];
              final selected = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: selected
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end:   Alignment.bottomRight,
                              colors: [
                                t.accent.withValues(alpha: 0.18),
                                t.accent.withValues(alpha: 0.10),
                              ],
                            ),
                            border: Td3.depthBorder(
                              topColor: t.accent.withValues(alpha: 0.35),
                              bottomColor: Td3.edgeMid,
                            ),
                            boxShadow: Td3.cardShadow(t.accent,
                                elev: Td3.elevLow),
                          )
                        : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          color: selected
                              ? t.accent
                              : t.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: selected
                                ? t.accent
                                : t.textSecondary,
                            fontSize: 9,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3InputField  (v1.1 — added onChanged callback)
// ─────────────────────────────────────────────────────────────────────────────

/// Recessed 3-D input field — sunken appearance when unfocused,
/// raised glowing border when focused.
class Td3InputField extends StatefulWidget {
  final TextEditingController controller;
  final String  label;
  final String  hint;
  final IconData icon;
  final bool    numeric;
  final bool    required;
  final bool    readOnly;
  final String? Function(String?)? validator;
  final Widget? suffixWidget;
  /// Optional callback fired on every text change (forwards to TextFormField).
  final ValueChanged<String>? onChanged;

  const Td3InputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.numeric   = false,
    this.required  = true,
    this.readOnly  = false,
    this.validator,
    this.suffixWidget,
    this.onChanged,
  });

  @override
  State<Td3InputField> createState() => _Td3InputFieldState();
}

class _Td3InputFieldState extends State<Td3InputField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final focused = _focused;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: focused
            ? t.cardBg
            : t.cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: focused
            ? Border.all(
                color: t.accent.withValues(alpha: 0.70),
                width: 1.5)
            : Td3.depthBorder(
                topColor:    Colors.white.withValues(alpha: 0.07),
                bottomColor: Td3.edgeMid,
              ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.18),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
                ...Td3.cardShadow(t.accent, elev: Td3.elevLow),
              ]
            : [
                BoxShadow(
                    color: Td3.shadowDark,
                    blurRadius: 3,
                    spreadRadius: -1,
                    offset: const Offset(0, 1)),
              ],
      ),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextFormField(
          controller:   widget.controller,
          readOnly:     widget.readOnly,
          onChanged:    widget.onChanged,
          keyboardType: widget.numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: TextStyle(
              color: t.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14),
          decoration: InputDecoration(
            labelText:   widget.label,
            hintText:    widget.hint,
            labelStyle:  TextStyle(color: t.textSecondary, fontSize: 12),
            hintStyle:   TextStyle(color: t.stroke, fontSize: 13),
            prefixIcon:  Icon(widget.icon, color: t.textSecondary, size: 18),
            suffixIcon:  widget.suffixWidget,
            border:      InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
          validator: widget.validator ??
              (widget.required
                  ? (v) => (v == null || v.trim().isEmpty)
                      ? 'Required'
                      : null
                  : null),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Td3SectionHeader
// ─────────────────────────────────────────────────────────────────────────────

class Td3SectionHeader extends StatelessWidget {
  final String text;
  final Color? accentColor;

  const Td3SectionHeader(this.text, {super.key, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final c = accentColor ?? t.accent;
    return Row(
      children: [
        Container(
          width: 3, height: 14,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end:   Alignment.bottomCenter,
              colors: [_lighten(c, 0.18), c, _darken(c, 0.15)],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                  color: c.withValues(alpha: 0.45),
                  blurRadius: 4,
                  offset: const Offset(0, 1)),
            ],
          ),
        ),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
            height: 0.5,
            color: Colors.white.withValues(alpha: 0.10)),
        Divider(
            height: 0.5,
            color: t.stroke.withValues(alpha: 0.60)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainters
// ─────────────────────────────────────────────────────────────────────────────

class _GlossPainter extends CustomPainter {
  final BorderRadius radius;
  final double       opacity;
  const _GlossPainter({required this.radius, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft:     radius.topLeft,
      topRight:    radius.topRight,
      bottomLeft:  radius.bottomLeft,
      bottomRight: radius.bottomRight,
    );
    canvas.clipRRect(rrect);

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end:   Alignment.center,
        colors: [
          Colors.white.withValues(alpha: opacity),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.55),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GlossPainter old) => old.opacity != opacity;
}

// ─────────────────────────────────────────────────────────────────────────────
// Colour helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .toColor();
}

Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .toColor();
}

// ─────────────────────────────────────────────────────────────────────────────
// Extension helpers
// ─────────────────────────────────────────────────────────────────────────────

extension Td3WidgetExt on Widget {
  Widget td3Card({
    Color?  color,
    Color?  accentColor,
    double  elevation = Td3.elevMid,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
  }) =>
      Td3Card(
        color:        color,
        accentColor:  accentColor,
        elevation:    elevation,
        padding:      padding,
        borderRadius: borderRadius,
        onTap:        onTap,
        child: this,
      );
}
