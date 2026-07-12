import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pump_station_provider.dart';
import '../data/repositories/pump_station_repository.dart';
import 'pump_station_detail_screen.dart';

class PumpStationsScreen extends ConsumerStatefulWidget {
  const PumpStationsScreen({super.key});

  @override
  ConsumerState<PumpStationsScreen> createState() => _PumpStationsScreenState();
}

class _PumpStationsScreenState extends ConsumerState<PumpStationsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'operational':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'operational':
        return Icons.check_circle;
      case 'maintenance':
        return Icons.build;
      case 'critical':
        return Icons.warning;
      default:
        return Icons.power_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(pumpStationSearchQueryProvider);
    final statusFilter = ref.watch(pumpStationStatusFilterProvider);
    final stationsAsync = ref.watch(
      pumpStationsProvider(
        PumpStationFilter(
          search: searchQuery.isEmpty ? null : searchQuery,
          status: statusFilter,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pump Stations'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by status',
            onSelected: (value) {
              ref.read(pumpStationStatusFilterProvider.notifier).state = value;
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: null,
                child: Text('All'),
              ),
              const PopupMenuItem(
                value: 'operational',
                child: Text('Operational'),
              ),
              const PopupMenuItem(
                value: 'maintenance',
                child: Text('Maintenance'),
              ),
              const PopupMenuItem(
                value: 'critical',
                child: Text('Critical'),
              ),
              const PopupMenuItem(
                value: 'offline',
                child: Text('Offline'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                ref.read(pumpStationSearchQueryProvider.notifier).state = value;
              },
              decoration: InputDecoration(
                hintText: 'Search pump stations…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(pumpStationSearchQueryProvider.notifier)
                              .state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
          ),

          // ── Active filter chip ──────────────────────────────────
          if (statusFilter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(
                    statusFilter[0].toUpperCase() + statusFilter.substring(1),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    ref.read(pumpStationStatusFilterProvider.notifier).state =
                        null;
                  },
                ),
              ),
            ),

          // ── Stations List ───────────────────────────────────────
          Expanded(
            child: stationsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load stations',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(pumpStationsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (stations) {
                if (stations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.water_damage,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No pump stations found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try adjusting your search or filters',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(pumpStationsProvider);
                  },
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: stations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final station = stations[index];
                      return _PumpStationCard(
                        station: station,
                        statusColor: _statusColor(station.status),
                        statusIcon: _statusIcon(station.status),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PumpStationCard extends StatelessWidget {
  final PumpStation station;
  final Color statusColor;
  final IconData statusIcon;

  const _PumpStationCard({
    required this.station,
    required this.statusColor,
    required this.statusIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PumpStationDetailScreen(stationId: station.id),
            ),
          );
        },
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
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          station.status[0].toUpperCase() +
                              station.status.substring(1),
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      station.location,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Capacity bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Capacity',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${station.capacityPercent.toStringAsFixed(0)}%',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: station.capacityPercent / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        station.capacityPercent > 80
                            ? Colors.red
                            : station.capacityPercent > 60
                                ? Colors.orange
                                : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              if (station.district != null) ...[
                const SizedBox(height: 8),
                Text(
                  'District: ${station.district}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
