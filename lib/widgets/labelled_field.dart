// lib/widgets/labelled_field.dart
import 'package:flutter/material.dart';

class LabelledField extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const LabelledField({
    super.key,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value, style: valueStyle ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
