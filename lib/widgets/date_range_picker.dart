// lib/widgets/date_range_picker.dart
import 'package:flutter/material.dart';

class OpsDateRangePicker extends StatelessWidget {
  final DateTimeRange? value;
  final ValueChanged<DateTimeRange> onChanged;
  final String label;

  const OpsDateRangePicker({
    super.key,
    this.value,
    required this.onChanged,
    this.label = 'Select date range',
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.date_range, size: 18),
      label: Text(
        value == null ? label : '${_fmt(value!.start)} – ${_fmt(value!.end)}',
        style: const TextStyle(fontSize: 13),
      ),
      onPressed: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: value,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
