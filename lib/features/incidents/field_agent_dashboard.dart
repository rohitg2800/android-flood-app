import 'package:flutter/material.dart';

class FieldAgentDashboard extends StatelessWidget {
  const FieldAgentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Agent Dashboard')),
      body: Column(
        children: [
          // TODO: My assigned incidents
          // TODO: Update status buttons
          // TODO: Navigate to incident on map
          const Text('Assigned Incidents'),
          const Text('Tap to update status or navigate'),
        ],
      ),
    );
  }
}
