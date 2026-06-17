// lib/widgets/app_icon_box.dart  v1.0  (Step 9c)
// Premium centered icon container — gradient fill + subtle glow + perfect rounding.
library;

import 'package:flutter/material.dart';

class AppIconBox extends StatelessWidget {
  const AppIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size        = 40,
    this.iconSize,
    this.radius,
    this.glow        = false,
    this.borderWidth = 1.0,
  });

  const AppIconBox.small({
    super.key,
    required this.icon,
    required this.color,
  })  : size        = 32,
        iconSize    = 16,
        radius      = 9,
        glow        = false,
        borderWidth = 1.0;

  const AppIconBox.large({
    super.key,
    required this.icon,
    required this.color,
    this.glow = false,
  })  : size        = 48,
        iconSize    = 24,
        radius      = 14,
        borderWidth = 1.5;

  final IconData icon;
  final Color    color;
  final double   size;
  final double?  iconSize;
  final double?  radius;
  final bool     glow;
  final double   borderWidth;

  @override
  Widget build(BuildContext context) {
    final r   = radius  ?? size * 0.28;
    final iSz = iconSize ?? size * 0.44;

    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: borderWidth,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color:        color.withValues(alpha: 0.28),
                  blurRadius:   10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(icon, color: color, size: iSz),
      ),
    );
  }
}
