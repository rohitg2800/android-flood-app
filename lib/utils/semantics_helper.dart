// lib/utils/semantics_helper.dart
// OpsFlood — Module 9: Accessibility helpers
//
// Provides:
//  • SemanticsLabel       — wraps any widget with a custom semantic label
//  • SemanticsButton      — wraps tappable widgets with role=button
//  • SemanticsLiveRegion — marks dynamic content (alert banners) as live
//  • ExcludeDecoration    — suppresses purely decorative widgets from a11y tree
//  • focusOrder()        — returns FocusTraversalOrder for a given sortKey int

import 'package:flutter/material.dart';

/// Wraps [child] with a custom accessibility label.
class SemanticsLabel extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget child;
  const SemanticsLabel({
    super.key,
    required this.label,
    this.hint,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        hint:  hint,
        child: ExcludeSemantics(child: child),
      );
}

/// Wraps [child] with semantics role = button and an [onTap] action.
class SemanticsButton extends StatelessWidget {
  final String    label;
  final VoidCallback? onTap;
  final Widget    child;
  const SemanticsButton({
    super.key,
    required this.label,
    this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        label:     label,
        button:    true,
        onTap:     onTap,
        child:     ExcludeSemantics(child: child),
      );
}

/// Marks a widget as a live region (e.g. alert banner).
/// Screen readers will announce changes immediately.
class SemanticsLiveRegion extends StatelessWidget {
  final Widget child;
  const SemanticsLiveRegion({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child:      child,
      );
}

/// Hides purely decorative widgets from the accessibility tree.
class ExcludeDecoration extends StatelessWidget {
  final Widget child;
  const ExcludeDecoration({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: child);
}

/// Returns a [FocusTraversalOrder] widget for explicit tab-order control.
Widget focusOrder({required int order, required Widget child}) =>
    FocusTraversalOrder(
      order: NumericFocusOrder(order.toDouble()),
      child: child,
    );

/// Minimum touch-target enforcer (WCAG 2.5.5 — 44×44 dp).
class MinTouchTarget extends StatelessWidget {
  final Widget child;
  final double size;
  const MinTouchTarget({
    super.key,
    required this.child,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(
          minWidth:  size,
          minHeight: size,
        ),
        child: child,
      );
}
