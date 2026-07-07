import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FloodMapScreen extends StatefulWidget {
  const FloodMapScreen({super.key});
  @override
  State<FloodMapScreen> createState() => _FloodMapScreenState();
}

class _FloodMapScreenState extends State<FloodMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polygon> _floodZones = {};
  bool _showWaterLevels = true;
  bool _showAlertZones = true;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(25.5941, 85.1376), // Bihar, India
    zoom: 7.5,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            polygons: _floodZones,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: MapType.hybrid,
          ),
          // Legend overlay
          Positioned(
            bottom: 100,
            left: 16,
            child: _buildLegend(),
          ),
          // Toggle controls
          Positioned(
            top: 50,
            right: 16,
            child: _buildControls(),
          ),
          // Water level stations button
          Positioned(
            bottom: 30,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFF1E90FF),
              onPressed: _loadWaterLevelStations,
              child: const Icon(Icons.water),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628).withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendItem(Colors.red, 'Critical Zone'),
          _legendItem(Colors.orange, 'High Risk Zone'),
          _legendItem(Colors.yellow, 'Medium Risk'),
          _legendItem(Colors.green, 'Safe Zone'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );

  Widget _buildControls() {
    return Column(
      children: [
        _toggleChip('Water Levels', _showWaterLevels, (v) => setState(() => _showWaterLevels = v)),
        const SizedBox(height: 8),
        _toggleChip('Alert Zones', _showAlertZones, (v) => setState(() => _showAlertZones = v)),
      ],
    );
  }

  Widget _toggleChip(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      selected: value,
      onSelected: onChanged,
      backgroundColor: const Color(0xFF1A2744),
      selectedColor: const Color(0xFF1E90FF),
      checkmarkColor: Colors.white,
    );
  }

  void _loadWaterLevelStations() {
    // TODO: Fetch from Neon DB via API
  }
}
