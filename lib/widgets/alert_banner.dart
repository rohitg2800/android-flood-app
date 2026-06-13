// lib/widgets/alert_banner.dart
import 'package:flutter/material.dart';

class AlertBanner extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback? onDismiss;

  const AlertBanner({
    super.key,
    required this.message,
    this.color = Colors.red,
    this.icon = Icons.warning_amber_rounded,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
            if (onDismiss != null)
              IconButton(icon: Icon(Icons.close, color: color, size: 18), onPressed: onDismiss),
          ],
        ),
      ),
    );
  }
}
