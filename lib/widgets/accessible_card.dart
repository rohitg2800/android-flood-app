// lib/widgets/accessible_card.dart  Step 5.3
// Drop-in Semantics wrappers for every major card / interactive widget.
// Import this file and replace bare Container/Card usages with these.
//
// Usage examples:
//   AccessibleCard(label: 'Patna gauge — CRITICAL', child: _GaugeCard(...))
//   AccessibleButton(label: 'Watch Patna station', onTap: ..., child: ...)
//   AccessibleStatusBadge(label: 'Risk level: CRITICAL', child: Badge(...))

import 'package:flutter/material.dart';

// ── AccessibleCard ───────────────────────────────────────────────────────────────
/// Wraps any widget in a [Semantics] node labelled as a non-interactive card.
/// Use for gauge cards, stat cells, ML prediction cards.
class AccessibleCard extends StatelessWidget {
  final String  label;
  final Widget  child;
  final String? hint;

  const AccessibleCard({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:     label,
      hint:      hint,
      container: true,
      child:     ExcludeSemantics(child: child),
    );
  }
}

// ── AccessibleButton ─────────────────────────────────────────────────────────────
/// Wraps a tappable widget ensuring a minimum 48×48 touch target
/// and a proper button Semantics node.
class AccessibleButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  final Widget       child;
  final String?      hint;
  final bool         enabled;

  const AccessibleButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.hint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:   label,
      hint:    hint,
      button:  true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: child,
        ),
      ),
    );
  }
}

// ── AccessibleStatusBadge ─────────────────────────────────────────────────────────
/// For colour-coded risk badges. Announces the label so colour is not
/// the only means of conveying information (WCAG 1.4.1).
class AccessibleStatusBadge extends StatelessWidget {
  final String label;    // e.g. "Risk level: CRITICAL"
  final Widget child;

  const AccessibleStatusBadge({
    super.key,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:     label,
      container: true,
      child:     ExcludeSemantics(child: child),
    );
  }
}

// ── AccessibleListTile ────────────────────────────────────────────────────────────
/// For station/city rows in lists — announces city, river, and risk level
/// as a single coherent announcement instead of reading four separate nodes.
class AccessibleListTile extends StatelessWidget {
  final String       city;
  final String       river;
  final String       riskLevel;
  final VoidCallback onTap;
  final Widget       child;

  const AccessibleListTile({
    super.key,
    required this.city,
    required this.river,
    required this.riskLevel,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:   '$city, $river River, risk level $riskLevel',
      button:  true,
      hint:    'Double-tap to view details',
      child: GestureDetector(
        onTap:    onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: ExcludeSemantics(child: child),
        ),
      ),
    );
  }
}

// ── AccessibleMapMarker ───────────────────────────────────────────────────────────
/// 48×48 minimum tap target for flutter_map markers (Step 5.4).
/// Wraps the marker icon in an opaque hit-test area.
class AccessibleMapMarker extends StatelessWidget {
  final String       label;    // e.g. "Patna — CRITICAL"
  final VoidCallback onTap;
  final Widget       child;

  const AccessibleMapMarker({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:  label,
      button: true,
      hint:   'Double-tap to view station details',
      child: GestureDetector(
        onTap:    onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width:  48,
          height: 48,
          child: Center(child: child),
        ),
      ),
    );
  }
}
