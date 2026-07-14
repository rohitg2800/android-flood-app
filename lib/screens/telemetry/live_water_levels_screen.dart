import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/water_level_stream_provider.dart';
import '../../widgets/telemetry/water_level_card.dart';

class LiveWaterLevelsScreen extends ConsumerWidget {
  const LiveWaterLevelsScreen({
    super.key,
    this.stateFilter,
  });

  final String? stateFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncReadings = stateFilter == null
        ? ref.watch(waterLevelStreamProvider)
        : ref.watch(waterLevelByStateProvider(stateFilter!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Water Levels'),
      ),
      body: asyncReadings.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('No live water level data available.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(waterLevelStreamProvider);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return WaterLevelCard(reading: items[index]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Live feed error: $error'),
        ),
      ),
    );
  }
}
