// lib/widgets/app_back_button.dart  back-v1
//
// Drop-in back button for any AppBar.
// • Pops if the route stack has more than one entry.
// • Falls back to Routes.shell (Home tab) if there's nowhere to go back to.
// • Smart label: shows previous route's display name if available.
//
// Usage:
//   AppBar(
//     leading: const AppBackButton(),
//     ...
//   )

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_router.dart';

class AppBackButton extends StatelessWidget {
  /// Override the tooltip / semantics label.
  final String? label;

  /// Override the icon (defaults to arrow_back_ios_new_rounded).
  final IconData? icon;

  /// Called after the pop / navigation happens.
  final VoidCallback? onPopped;

  const AppBackButton({super.key, this.label, this.icon, this.onPopped});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: label ?? (canPop ? 'Back' : 'Home'),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          if (canPop) {
            Navigator.of(context).pop();
          } else {
            // Nowhere to pop to — go to shell home tab
            Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.shell,
              (r) => false,
              arguments: 0,
            );
          }
          onPopped?.call();
        },
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: Icon(
            icon ?? Icons.arrow_back_ios_new_rounded,
            size: 17,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Wraps any screen with Android hardware-back + swipe-back handling.
/// Use this in AppRouter.onGenerateRoute to wrap every non-shell page.
class BackAwareRoute extends StatelessWidget {
  final Widget child;
  const BackAwareRoute({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Allow the pop — we handle the side-effect only
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) HapticFeedback.lightImpact();
      },
      child: child,
    );
  }
}
