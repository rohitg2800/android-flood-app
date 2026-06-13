// lib/widgets/sos_fab.dart
import 'package:flutter/material.dart';

class SosFab extends StatelessWidget {
  final VoidCallback onPressed;

  const SosFab({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.sos),
      label: const Text('SOS', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
