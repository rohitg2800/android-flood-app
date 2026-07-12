import 'package:flutter/material.dart';

class NewDashboardScreen extends StatelessWidget {
  const NewDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: const Center(
        child: Text('Dashboard loaded'),
      ),
    );
  }
}
