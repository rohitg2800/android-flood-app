// lib/utils/accessibility_helpers.dart
// OpsFlood — Accessibility helpers (Phase 1A)
// Wraps widgets with proper Semantics for WCAG 2.1 AA compliance.
library;

import 'package:flutter/material.dart';

/// Wrap any interactive widget with this to add a proper semantic label.
Widget semanticButton({
  required String label,
  required Widget child,
  String? hint,
  VoidCallback? onTap,
}) {
  return Semantics(
    label: label,
    hint: hint,
    button: true,
    onTap: onTap,
    child: child,
  );
}

/// Severity chip that communicates via BOTH color AND icon + text (not color-only).
/// Drop-in replacement for plain color badge throughout the app.
class SeverityChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final double fontSize;

  const SeverityChip({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Severity: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon button with guaranteed 48x48 dp touch target and tooltip.
class AccessibleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;
  final double iconSize;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(icon, color: color, size: iconSize),
          ),
        ),
      ),
    );
  }
}

/// Maps riskLevel string to severity icon (used with SeverityChip to avoid color-only).
IconData severityIcon(String riskLevel) {
  switch (riskLevel.toUpperCase()) {
    case 'EMERGENCY':
      return Icons.emergency_rounded;
    case 'CRITICAL':
      return Icons.warning_rounded;
    case 'SEVERE':
      return Icons.warning_amber_rounded;
    case 'MODERATE':
      return Icons.info_rounded;
    default:
      return Icons.check_circle_rounded;
  }
}

/// Maps riskLevel string to Hindi severity label for bilingual display.
String severityHindi(String riskLevel) {
  switch (riskLevel.toUpperCase()) {
    case 'EMERGENCY':
      return 'आपातकाल';
    case 'CRITICAL':
      return 'खतरा';
    case 'SEVERE':
      return 'चेतावनी';
    case 'MODERATE':
      return 'सतर्क';
    default:
      return 'सामान्य';
  }
}
