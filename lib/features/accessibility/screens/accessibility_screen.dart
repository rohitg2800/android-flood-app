import 'package:flutter/material.dart';

class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Accessibility controls are temporarily unavailable on this branch.',
        ),
      ),
    );
  }
}
