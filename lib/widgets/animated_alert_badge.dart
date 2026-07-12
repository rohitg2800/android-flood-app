// lib/widgets/animated_alert_badge.dart
// EQUINOX-BH — Pulsing badge shown on nav items when critical alerts exist.
library;

import 'package:flutter/material.dart';

/// A pulsing red badge with a count, used on the Alerts nav tab.
class AnimatedAlertBadge extends StatefulWidget {
  final int count;
  final Color color;

  const AnimatedAlertBadge({
    super.key,
    required this.count,
    this.color = Colors.red,
  });

  @override
  State<AnimatedAlertBadge> createState() => _AnimatedAlertBadgeState();
}

class _AnimatedAlertBadgeState extends State<AnimatedAlertBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count <= 0) return const SizedBox.shrink();
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(10),
        ),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        child: Text(
          widget.count > 99 ? '99+' : '${widget.count}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
