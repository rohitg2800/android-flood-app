import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../constants/bihar_constants.dart';
import '../providers/flood_providers.dart';

class LiveStationsScreen extends ConsumerWidget {
  const LiveStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppPalette.navy0,
      appBar: AppBar(
        backgroundColor: AppPalette.navy1,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Stations', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Bihar WRD Monitoring Network', style: TextStyle(fontSize: 12, color: AppPalette.textMuted)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // River filter chips
          _RiverFilterChips(),
          const SizedBox(height: 16),
          // Stations list
          ...kBiharStations.map((s) => _StationCard(station: s, ref: ref)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _RiverFilterChips extends StatefulWidget {
  @override
  State<_RiverFilterChips> createState() => _RiverFilterChipsState();
}

class _RiverFilterChipsState extends State<_RiverFilterChips> {
  String _selected = 'All';
  final List<String> _rivers = ['All', 'Ganga', 'Koshi', 'Gandak', 'Bagmati', 'Burhi Gandak', 'Sone', 'Mahananda', 'Kamla'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _rivers.map((r) {
          final selected = _selected == r;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(r),
              selected: selected,
              onSelected: (_) => setState(() => _selected = r),
              selectedColor: AppPalette.blue1.withOpacity(0.25),
              backgroundColor: AppPalette.navy1,
              labelStyle: TextStyle(
                color: selected ? AppPalette.blue1 : AppPalette.textMuted,
                fontSize: 12,
              ),
              side: BorderSide(color: selected ? AppPalette.blue1 : AppPalette.divider),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final Map<String, dynamic> station;
  final WidgetRef ref;
  const _StationCard({required this.station, required this.ref});

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryProvider((
      state: kBiharState,
      station: station['name'] as String,
      limit: 1,
    )));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.navy1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.green,
                ),
              ),
              const SizedBox(width: 8),
              Text(station['name'] as String,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppPalette.blue1.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(station['river'] as String,
                    style: const TextStyle(fontSize: 11, color: AppPalette.blue1)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ThresholdChip(
                  label: 'Danger', value: '${station['danger_m']} m',
                  color: AppPalette.red),
              _ThresholdChip(
                  label: 'Warning', value: '${station['warning_m']} m',
                  color: AppPalette.orange),
              _ThresholdChip(
                  label: 'Lat/Lon',
                  value: '${station['lat']}, ${station['lon']}',
                  color: AppPalette.textMuted),
            ],
          ),
          telemetry.when(
            data: (data) {
              final nodes = (data['data'] as List?) ?? [];
              if (nodes.isEmpty) return const SizedBox.shrink();
              final latest = nodes.first as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppPalette.navy2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.water_rounded, color: AppPalette.blue1, size: 16),
                      const SizedBox(width: 8),
                      Text('Level: ${latest['river_level_m'] ?? '--'} m',
                          style: const TextStyle(fontSize: 13, color: Colors.white)),
                      const Spacer(),
                      Text(latest['status']?.toString() ?? 'N/A',
                          style: const TextStyle(fontSize: 12, color: AppPalette.textMuted)),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(color: AppPalette.blue1, backgroundColor: AppPalette.navy2),
            ),
            error: (e, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ThresholdChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ThresholdChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: color)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
