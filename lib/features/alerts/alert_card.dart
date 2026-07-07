import 'package:flutter/material.dart';
import 'alert_model.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  const AlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Color(alert.severityColor),
              width: 5,
            ),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(alert.description),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    label: Text(alert.severity.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 11)),
                    backgroundColor: Color(alert.severityColor),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  if (alert.areaName != null)
                    Text('📍 ${alert.areaName}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
