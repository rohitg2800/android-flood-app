// lib/screens/state_matrix_screen.dart  v2 — explicit back button
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../widgets/app_back_button.dart';
import '../providers/flood_data_provider.dart';

class StateMatrixScreen extends ConsumerWidget {
  const StateMatrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t    = RiverColors.of(context);
    final data = ref.watch(floodDataProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        leading: const AppBackButton(),
        title: Text(
          'State Matrix',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: t.accent),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(floodDataProvider),
          ),
        ],
        elevation: 0,
      ),
      body: data.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: t.accent)),
        error: (e, _) => Center(
          child: Text('Error loading data',
              style: TextStyle(color: t.textSecondary)),
        ),
        data: (stations) => ListView.builder(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      s.riverName,
                      style: TextStyle(
                          color: t.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    s.currentLevel.toStringAsFixed(2),
                    style: TextStyle(
                        color: t.accent, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
