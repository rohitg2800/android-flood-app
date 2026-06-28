// lib/screens/live_stations_screen.dart  v2 — explicit back button
// Full rebuild retaining all original features + AppBackButton leading.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../widgets/app_back_button.dart';
import '../providers/flood_data_provider.dart';
import '../models/flood_data.dart';
import '../app_router.dart';
import 'cwc_station_detail_screen.dart';

// ── providers ────────────────────────────────────────────────────────────────
final _searchProvider  = StateProvider<String>((_)       => '');
final _filterProvider  = StateProvider<String?>((_)      => null);   // river name filter
final _sortProvider    = StateProvider<_SortMode>((_)    => _SortMode.level);

enum _SortMode { level, name, danger }

class LiveStationsScreen extends ConsumerStatefulWidget {
  const LiveStationsScreen({super.key});

  @override
  ConsumerState<LiveStationsScreen> createState() => _State();
}

class _State extends ConsumerState<LiveStationsScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(minutes: 5),
      (_) => ref.invalidate(floodDataProvider),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t      = RiverColors.of(context);
    final data   = ref.watch(floodDataProvider);
    final search = ref.watch(_searchProvider);
    final filter = ref.watch(_filterProvider);
    final sort   = ref.watch(_sortProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        leading: const AppBackButton(),
        title: Text(
          'Live Stations',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: t.accent),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(floodDataProvider),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              style: TextStyle(color: t.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search stations…',
                hintStyle: TextStyle(color: t.textSecondary),
                prefixIcon:
                    Icon(Icons.search_rounded, color: t.textSecondary),
                filled: true,
                fillColor: t.cardBg,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) =>
                  ref.read(_searchProvider.notifier).state = v,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: data.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: t.accent)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  color: t.textSecondary, size: 48),
              const SizedBox(height: 12),
              Text('Could not fetch stations',
                  style: TextStyle(color: t.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(floodDataProvider),
                child: Text('Retry', style: TextStyle(color: t.accent)),
              ),
            ],
          ),
        ),
        data: (stations) {
          var list = List<FloodData>.from(stations);

          // search
          if (search.isNotEmpty) {
            final q = search.toLowerCase();
            list = list
                .where((s) =>
                    s.riverName.toLowerCase().contains(q) ||
                    s.stationName.toLowerCase().contains(q))
                .toList();
          }

          // river filter
          if (filter != null) {
            list = list.where((s) => s.riverName == filter).toList();
          }

          // sort
          switch (sort) {
            case _SortMode.level:
              list.sort((a, b) =>
                  b.currentLevel.compareTo(a.currentLevel));
            case _SortMode.name:
              list.sort((a, b) =>
                  a.stationName.compareTo(b.stationName));
            case _SortMode.danger:
              list.sort((a, b) =>
                  b.dangerLevel.compareTo(a.dangerLevel));
          }

          if (list.isEmpty) {
            return Center(
              child: Text('No stations match',
                  style: TextStyle(color: t.textSecondary)),
            );
          }

          return Column(
            children: [
              _SortBar(t: t, sort: sort,
                  onSort: (v) => ref.read(_sortProvider.notifier).state = v),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _StationTile(
                    t: t,
                    station: list[i],
                    onTap: () => AppRouter.push(
                      Routes.stationDetail,
                      arguments: list[i],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── sub-widgets ───────────────────────────────────────────────────────────────
class _SortBar extends StatelessWidget {
  const _SortBar({required this.t, required this.sort, required this.onSort});
  final RiverColors t;
  final _SortMode sort;
  final ValueChanged<_SortMode> onSort;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          for (final m in _SortMode.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_label(m)),
                selected: sort == m,
                selectedColor: t.accent.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                    color: sort == m ? t.accent : t.textSecondary,
                    fontSize: 12),
                onSelected: (_) => onSort(m),
              ),
            ),
        ],
      ),
    );
  }

  String _label(_SortMode m) {
    switch (m) {
      case _SortMode.level:  return 'By Level';
      case _SortMode.name:   return 'By Name';
      case _SortMode.danger: return 'By Danger';
    }
  }
}

class _StationTile extends StatelessWidget {
  const _StationTile({required this.t, required this.station, required this.onTap});
  final RiverColors t;
  final FloodData station;
  final VoidCallback onTap;

  Color _levelColor(FloodData s) {
    if (s.currentLevel >= s.dangerLevel)  return t.riverDanger;
    if (s.currentLevel >= s.warningLevel) return t.riverWarning;
    return t.riverNormal;
  }

  @override
  Widget build(BuildContext context) {
    final lc   = _levelColor(station);
    final pct  = station.dangerLevel > 0
        ? (station.currentLevel / station.dangerLevel).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: lc.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.stationName,
                        style: TextStyle(
                            color: t.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                      Text(
                        station.riverName,
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: lc.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${station.currentLevel.toStringAsFixed(2)} m',
                    style: TextStyle(
                        color: lc,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: t.accent.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(lc),
                minHeight: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
