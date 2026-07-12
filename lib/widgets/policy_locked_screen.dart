// lib/widgets/policy_locked_screen.dart
// OpsFlood — PolicyLockedScreen
// Displayed when a data source policy restricts access.
library;

import 'package:flutter/material.dart';

class PolicyLockedScreen extends StatelessWidget {
  const PolicyLockedScreen({super.key, this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Access Restricted',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (reason != null) ...[
                const SizedBox(height: 8),
                Text(
                  reason!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
