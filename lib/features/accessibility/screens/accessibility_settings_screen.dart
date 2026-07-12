import 'package:flutter/material.dart';

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility Settings')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Accessibility settings are temporarily unavailable while this feature is being integrated.',
        ),
      ),
    );
  }
}
