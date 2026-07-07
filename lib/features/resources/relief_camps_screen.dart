// Module 6: Relief Camps Screen
import 'package:flutter/material.dart';
import 'relief_camp_model.dart';

class ReliefCampsScreen extends StatelessWidget {
  const ReliefCampsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Load from Neon via API
    final List<ReliefCamp> camps = [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relief Camps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Filter by district, medical, capacity
            },
          ),
        ],
      ),
      body: camps.isEmpty
          ? const Center(child: Text('No active relief camps'))
          : ListView.builder(
              itemCount: camps.length,
              itemBuilder: (context, index) {
                final camp = camps[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.home, size: 36),
                    title: Text(camp.name),
                    subtitle: Text('${camp.district ?? ''} — ${camp.availableSpace}/${camp.capacity} available'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (camp.hasMedical)
                          const Icon(Icons.local_hospital, color: Colors.red, size: 18),
                        if (camp.hasFood)
                          const Icon(Icons.restaurant, color: Colors.orange, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
