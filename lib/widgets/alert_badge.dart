// lib/widgets/alert_badge.dart
//
// Reusable badge widget — shows unread threshold alert count on nav icons.
// Uses Riverpod ConsumerWidget, matching the rest of the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/alerts_badge_provider.dart';

class AlertBadge extends ConsumerWidget {
  final Widget child;
  const AlertBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(criticalAlertCountProvider);
    if (count == 0) return child;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: Colors.red,
      child: child,
    );
  }
}
