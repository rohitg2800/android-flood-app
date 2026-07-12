// Module 7: Admin Dashboard Screen
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _DashboardCard(
            title: 'Active Alerts',
            icon: Icons.warning_amber,
            color: Colors.red,
            value: '—',
            onTap: () {
              // TODO: Navigate to alerts management
            },
          ),
          _DashboardCard(
            title: 'Open Incidents',
            icon: Icons.report_problem,
            color: Colors.orange,
            value: '—',
            onTap: () {
              // TODO: Navigate to incidents list
            },
          ),
          _DashboardCard(
            title: 'Relief Camps',
            icon: Icons.home,
            color: Colors.blue,
            value: '—',
            onTap: () {
              // TODO: Navigate to camps management
            },
          ),
          _DashboardCard(
            title: 'Field Agents',
            icon: Icons.people,
            color: Colors.green,
            value: '—',
            onTap: () {
              // TODO: Navigate to user management
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
