// lib/widgets/dashboard/alert_activity_log.dart
// Extracted from dashboard_screen.dart — scrollable log of recent risk-level transitions.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AlertActivityLog extends StatelessWidget {
  final List<AlertEvent> events;

  const AlertActivityLog({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('No recent transitions',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (_, i) => _EventRow(event: events[i]),
    );
  }
}

/// Immutable event data class — replaces the private _AlertEvent in dashboard_screen.
class AlertEvent {
  final String city;
  final String river;
  final String fromLevel;
  final String toLevel;
  final double level;
  final DateTime time;

  const AlertEvent({
    required this.city,
    required this.river,
    required this.fromLevel,
    required this.toLevel,
    required this.level,
    required this.time,
  });
}

class _EventRow extends StatelessWidget {
  final AlertEvent event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(fmt.format(event.time),
              style: const TextStyle(fontSize: 11, color: Colors.white38)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: event.city,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12)),
                TextSpan(
                    text: '  ${event.fromLevel} → ${event.toLevel}',
                    style: TextStyle(
                        fontSize: 11,
                        color: event.toLevel == 'CRITICAL'
                            ? Colors.red
                            : Colors.orange)),
              ]),
            ),
          ),
          Text(
            '${event.level.toStringAsFixed(1)} m',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
