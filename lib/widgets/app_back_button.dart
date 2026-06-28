// lib/widgets/app_back_button.dart
// Shared back button widget used across all push-nav screens.
// Automatically hides itself when there is nothing to pop.
library;

import 'package:flutter/material.dart';

/// A standardised back-button for use in AppBar.leading.
/// Uses [Navigator.maybePop] so it is safe on root routes too.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.color,
    this.tooltip = 'Back',
  });

  final Color? color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.of(context);
    if (!nav.canPop()) return const SizedBox.shrink();
    return IconButton(
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        color: color ?? Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
        size: 20,
      ),
      tooltip: tooltip,
      onPressed: () => nav.pop(),
    );
  }
}
