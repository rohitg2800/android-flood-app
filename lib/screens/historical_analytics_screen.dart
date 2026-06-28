// lib/screens/historical_analytics_screen.dart  v2 — explicit back button
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../widgets/app_back_button.dart';
import '../providers/flood_data_provider.dart';

enum _Period { week, month, year }

final _periodProvider = StateProvider<_Period>((_) => _Period.month);

class HistoricalAnalyticsScreen extends ConsumerWidget {
  const HistoricalAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t      = RiverColors.of(context);
    final period = ref.watch(_periodProvider);
    final data   = ref.watch(floodDataProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        leading: const AppBackButton(),
        title: Text(
          'Historical Analytics',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Period selector
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                for (final p in _Period.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Center(
                          child: Text(_label(p),
                              style: const TextStyle(fontSize: 12))),
                        selected: period == p,
                        selectedColor: t.accent.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                            color:
                                period == p ? t.accent : t.textSecondary),
                        onSelected: (_) => ref
                            .read(_periodProvider.notifier)
                            .state = p,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: data.when(
              loading: () => Center(
                  child: CircularProgressIndicator(color: t.accent)),
              error: (e, _) => Center(
                child: Text('Error loading history',
                    style: TextStyle(color: t.textSecondary)),
              ),
              data: (stations) => ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: stations.length,
                itemBuilder: (_, i) {
                  final s = stations[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.cardBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.stationName,
                            style: TextStyle(
                                color: t.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                        Text(
                          '${period.name} avg: ${s.currentLevel.toStringAsFixed(2)} m',
                          style: TextStyle(
                              color: t.accent, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _label(_Period p) {
    switch (p) {
      case _Period.week:  return 'Week';
      case _Period.month: return 'Month';
      case _Period.year:  return 'Year';
    }
  }
}
