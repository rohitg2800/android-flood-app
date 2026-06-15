// lib/screens/state_matrix_screen.dart  (v5.1 — 15 Jun 2026)
//
// v5.1 — Add static `route` constant used by analytics_dashboard_screen
//   for named-route navigation.
//
// v5.0 — AutoRefreshMixin + ref.watch(biharLiveProvider).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../providers/bihar_live_provider.dart';

class StateMatrixScreen extends ConsumerStatefulWidget {
  const StateMatrixScreen({super.key});

  /// Named route used by Navigator.pushNamed.
  static const String route = '/state-matrix';

  @override
  ConsumerState<StateMatrixScreen> createState() => _StateMatrixScreenState();
}

class _StateMatrixScreenState extends ConsumerState<StateMatrixScreen>
    with AutoRefreshMixin {
  @override
  Widget build(BuildContext context) {
    final liveAsync = ref.watch(biharLiveProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('State Matrix'),
        actions: [
          IconButton(
            icon:     const Icon(Icons.refresh),
            tooltip:  'Refresh now',
            onPressed: onManualRefresh,
          ),
        ],
      ),
      body: liveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (live) => refreshIndicator(
          child: _buildMatrix(context, live),
        ),
      ),
    );
  }

  Widget _buildMatrix(BuildContext context, BiharLiveState live) {
    final byDistrict = <String, List<BiharStationData>>{};
    for (final s in live.stations) {
      byDistrict.putIfAbsent(s.district.isEmpty ? 'Unknown' : s.district,
          () => []).add(s);
    }

    final districts = byDistrict.keys.toList()..sort();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (lastFetchedLabel.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                lastFetchedLabel,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        for (final district in districts)
          SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    district,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              SliverGrid.builder(
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing:    8,
                  crossAxisSpacing:   8,
                  childAspectRatio:   1.6,
                ),
                itemCount: byDistrict[district]!.length,
                itemBuilder: (ctx, i) {
                  final s = byDistrict[district]![i];
                  final color = s.isCritical
                      ? Colors.red
                      : s.isSevere
                          ? Colors.deepOrange
                          : s.isWarning
                              ? Colors.orange
                              : Colors.green;
                  return Card(
                    color: color.withOpacity(0.08),
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            s.city,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.riskLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${s.currentLevel?.toStringAsFixed(1) ?? '--'} m',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
      ],
    );
  }
}
