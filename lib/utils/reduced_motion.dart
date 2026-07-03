// lib/utils/reduced_motion.dart
// OpsFlood — Module 9: Reduced-motion helpers
//
// Reads MediaQuery.of(context).disableAnimations and returns:
//  • zero-duration Duration when user has enabled "reduce motion" in OS
//  • normal Duration otherwise
//
// Usage:
//   AnimatedContainer(
//     duration: motionDuration(context, const Duration(milliseconds: 250)),
//     ...
//   )

import 'package:flutter/material.dart';

/// Returns [normal] duration unless the OS reduce-motion flag is set,
/// in which case it returns [Duration.zero].
Duration motionDuration(
  BuildContext context,
  Duration normal, [
  Duration reduced = Duration.zero,
]) {
  final disable = MediaQuery.of(context).disableAnimations;
  return disable ? reduced : normal;
}

/// Returns a curve: [Curves.easeInOutCubic] normally,
/// [Curves.linear] when reduce-motion is on (avoids
/// vestibular-triggering easing).
Curve motionCurve(BuildContext context) =>
    MediaQuery.of(context).disableAnimations
        ? Curves.linear
        : Curves.easeInOutCubic;

/// Builder version — exposes [reduceMotion] bool.
class MotionAwareBuilder extends StatelessWidget {
  final Widget Function(BuildContext ctx, bool reduceMotion) builder;
  const MotionAwareBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => builder(
        context,
        MediaQuery.of(context).disableAnimations,
      );
}
