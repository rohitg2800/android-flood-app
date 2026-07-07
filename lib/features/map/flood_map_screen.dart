import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'map_bloc.dart';
import 'map_event.dart';
import 'map_state.dart';

class FloodMapScreen extends StatefulWidget {
  const FloodMapScreen({super.key});

  @override
  State<FloodMapScreen> createState() => _FloodMapScreenState();
}

class _FloodMapScreenState extends State<FloodMapScreen> {
  GoogleMapController? _mapController;
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(25.5941, 85.1376), // Bihar, India
    zoom: 7,
  );

  @override
  void initState() {
    super.initState();
    context.read<MapBloc>().add(LoadFloodMapData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flood Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () => context.read<MapBloc>().add(CenterOnUserLocation()),
          ),
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () => _showLayerOptions(context),
          ),
        ],
      ),
      body: BlocBuilder<MapBloc, MapState>(
        builder: (ctx, state) {
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _initialPosition,
                onMapCreated: (controller) => _mapController = controller,
                markers: state is MapLoaded ? state.markers : {},
                polygons: state is MapLoaded ? state.floodZonePolygons : {},
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
              ),
              if (state is MapLoading)
                const Center(child: CircularProgressIndicator()),
              if (state is MapLoaded)
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: _LegendCard(),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showLayerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.warning), title: const Text('Flood Zones'), onTap: () {}),
          ListTile(leading: const Icon(Icons.water), title: const Text('Water Levels'), onTap: () {}),
          ListTile(leading: const Icon(Icons.local_hospital), title: const Text('Relief Camps'), onTap: () {}),
        ],
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Risk Zones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            _LegendItem(color: Colors.red, label: 'High Risk'),
            _LegendItem(color: Colors.orange, label: 'Medium Risk'),
            _LegendItem(color: Colors.green, label: 'Low Risk'),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
