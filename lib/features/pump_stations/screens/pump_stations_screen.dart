import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/features/pump_stations/models/pump_station.dart';
import 'package:equinox_flood/features/pump_stations/providers/pump_station_provider.dart';

class PumpStationsScreen extends ConsumerWidget {
  const PumpStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(pumpStationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: Text(
          'Pump Stations',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => ref.invalidate(pumpStationsProvider),
          ),
        ],
      ),
      body: stationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFFF4C4C), size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load stations',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(pumpStationsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (stations) => stations.isEmpty
            ? _EmptyState()
            : RefreshIndicator(
                color: const Color(0xFF00D4FF),
                onRefresh: () async => ref.invalidate(pumpStationsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: stations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _PumpStationCard(station: stations[i]),
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.water_damage_outlined,
              size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'No pump stations found',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PumpStationCard extends StatelessWidget {
  final PumpStation station;
  const _PumpStationCard({required this.station});

  Color get _statusColor {
    switch (station.status) {
      case PumpStationStatus.operational:
        return const Color(0xFF00E676);
      case PumpStationStatus.faulty:
        return const Color(0xFFFF6D00);
      case PumpStationStatus.offline:
        return const Color(0xFFFF4C4C);
      case PumpStationStatus.maintenance:
        return const Color(0xFFFFD600);
    }
  }

  String get _statusLabel {
    switch (station.status) {
      case PumpStationStatus.operational:
        return 'Operational';
      case PumpStationStatus.faulty:
        return 'Faulty';
      case PumpStationStatus.offline:
        return 'Offline';
      case PumpStationStatus.maintenance:
        return 'Maintenance';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    station.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _statusColor.withOpacity(0.5), width: 1),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: Color(0xFF00D4FF)),
                const SizedBox(width: 4),
                Text(
                  station.location,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (station.districtName != null) ...
              [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.map_outlined,
                        size: 14,
                        color: Colors.white.withOpacity(0.4)),
                    const SizedBox(width: 4),
                    Text(
                      station.districtName!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  label: 'Capacity',
                  value: '${station.capacityLitersPerSecond.toStringAsFixed(0)} L/s',
                  color: const Color(0xFF00D4FF),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Flow Rate',
                  value: '${station.currentFlowRate.toStringAsFixed(1)} L/s',
                  color: const Color(0xFF9B59B6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
