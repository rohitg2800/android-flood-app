import 'package:flutter/material.dart';

class FloodMapScreen extends StatefulWidget {
  const FloodMapScreen({super.key});

  @override
  State<FloodMapScreen> createState() => _FloodMapScreenState();
}

class _FloodMapScreenState extends State<FloodMapScreen> {
  // TODO: Initialize GoogleMapController
  // TODO: Load flood zones from Neon API
  // TODO: Add water level markers
  // TODO: Implement geofencing alerts

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flood Map')),
      body: const Center(child: Text('Google Maps — connect flood zones from Neon')),
    );
  }
}
