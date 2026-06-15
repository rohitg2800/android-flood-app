// lib/screens/bihar_river_map_screen.dart  (v7.1 — 15 Jun 2026)
//
// FIXES:
//   • s.lng → s.lon  (RiverStation has .lon not .lng)
//   • Added static const route = '/bihar-river-map'  (used by analytics_dashboard_screen)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../providers/real_time_river_provider.dart';
import '../models/river_station.dart';

class BiharRiverMapScreen extends ConsumerStatefulWidget {
  static const String route = '/bihar-river-map';

  const BiharRiverMapScreen({super.key});

  @override
  ConsumerState<BiharRiverMapScreen> createState() =>
      _BiharRiverMapScreenState();
}

class _BiharRiverMapScreenState extends ConsumerState<BiharRiverMapScreen>
    with AutoRefreshMixin {
  final _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final stations  = ref.watch(mergedStationsProvider);
    final isLoading = ref.watch(wrdIsLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bihar River Map'),
            if (lastFetchedLabel.isNotEmpty)
              Text(
                lastFetchedLabel,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon:     const Icon(Icons.refresh),
              tooltip:  'Refresh now',
              onPressed: onManualRefresh,
            ),
        ],
      ),
      body: refreshIndicator(
        child: FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(25.78, 85.17),
            initialZoom:   7,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.opsflood.app',
            ),
            MarkerLayer(
              markers: stations
                  .where((s) => s.current > 0)
                  .map((s) => _buildMarker(s))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildMarker(RiverStation s) {
    final pct = s.danger > 0
        ? (s.current / s.danger * 100).clamp(0, 150)
        : 0.0;
    final color = pct >= 100
        ? Colors.red
        : pct >= 85
            ? Colors.orange
            : Colors.green;

    return Marker(
      point:  LatLng(s.lat ?? 25.78, s.lon ?? 85.17),  // FIX: was s.lng
      width:  36,
      height: 36,
      child: GestureDetector(
        onTap: () => _showPopup(s),
        child: Icon(Icons.location_on, color: color, size: 32),
      ),
    );
  }

  void _showPopup(RiverStation s) {
    showModalBottomSheet(
      context:  context,
      builder:  (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.city,
                style: Theme.of(context).textTheme.titleLarge),
            Text('${s.river}  •  ${s.state}'),
            const SizedBox(height: 8),
            Text(
              'Level: ${s.current.toStringAsFixed(2)} m\n'
              'Warning: ${s.warning.toStringAsFixed(2)} m\n'
              'Danger: ${s.danger.toStringAsFixed(2)} m',
            ),
          ],
        ),
      ),
    );
  }
}
