// Module 4: Flood Map Screen
// flutter pub add google_maps_flutter
import 'package:flutter/material.dart';

class FloodMapScreen extends StatefulWidget {
  const FloodMapScreen({super.key});

  @override
  State<FloodMapScreen> createState() => _FloodMapScreenState();
}

class _FloodMapScreenState extends State<FloodMapScreen> {
  // TODO: Initialize GoogleMapController
  // TODO: Load flood zone polygons from Neon
  // TODO: Load water level markers from Neon
  // TODO: Implement geofencing for flood zone alerts

  static const _initialCameraPosition = {
    'lat': 25.5941,  // Bihar center
    'lng': 85.1376,
    'zoom': 7.0,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flood Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () {
              // TODO: Toggle map layers (flood zones, water levels, relief camps)
            },
            tooltip: 'Toggle Layers',
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Google Maps integration\nAdd google_maps_flutter package and API key',
          textAlign: TextAlign.center,
        ),
        // TODO: Replace with GoogleMap widget
        // GoogleMap(
        //   initialCameraPosition: CameraPosition(
        //     target: LatLng(_initialCameraPosition['lat']!, _initialCameraPosition['lng']!),
        //     zoom: _initialCameraPosition['zoom']!,
        //   ),
        //   polygons: _floodZones,
        //   markers: _waterLevelMarkers,
        //   onMapCreated: (controller) => _mapController = controller,
        // ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Center map on user location
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
