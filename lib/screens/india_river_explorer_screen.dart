// lib/screens/india_river_explorer_screen.dart  v2 — explicit back button
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../widgets/app_back_button.dart';
import '../providers/flood_data_provider.dart';

final _selectedRiverProvider = StateProvider<String?>((_) => null);

class IndiaRiverExplorerScreen extends ConsumerWidget {
  const IndiaRiverExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t      = RiverColors.of(context);
    final data   = ref.watch(floodDataProvider);
    final selRiv = ref.watch(_selectedRiverProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        leading: const AppBackButton(),
        title: Text(
          'India River Explorer',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (selRiv != null)
            TextButton(
              onPressed: () =>
                  ref.read(_selectedRiverProvider.notifier).state = null,
              child: Text('Clear',
                  style: TextStyle(
                      color: t.riverDanger, fontWeight: FontWeight.w700)),
            ),
        ],
        elevation: 0,
      ),
      body: data.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: t.accent)),
        error: (e, _) => Center(
          child: Text('Error loading river data',
              style: TextStyle(color: t.textSecondary)),
        ),
        data: (stations) {
          final rivers = stations.map((s) => s.riverName).toSet().toList()
            ..sort();

          final filtered = selRiv != null
              ? stations.where((s) => s.riverName == selRiv).toList()
              : stations;

          return Column(
            children: [
              // river chip filter bar
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: rivers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final r = rivers[i];
                    final sel = selRiv == r;
                    return ChoiceChip(
                      label: Text(r, style: const TextStyle(fontSize: 12)),
                      selected: sel,
                      selectedColor: t.accent.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                          color: sel ? t.accent : t.textSecondary),
                      onSelected: (_) => ref
                          .read(_selectedRiverProvider.notifier)
                          .state = sel ? null : r,
                    );
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final s = filtered[i];
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
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.stationName,
                                  style: TextStyle(
                                      color: t.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                                Text(
                                  s.riverName,
                                  style: TextStyle(
                                      color: t.textSecondary,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${s.currentLevel.toStringAsFixed(2)} m',
                            style: TextStyle(
                                color: t.accent,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
