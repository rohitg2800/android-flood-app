// lib/screens/rainfall_forecast_screen.dart — v3.0 Premium Redesign
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/core/theme/river_theme.dart' as core_theme;
import '../models/flood_prediction.dart';
import '../providers/bihar_prediction_provider.dart';
import '../l10n/context_l10n.dart';

// ── Search provider ──────────────────────────────────────────────────────────
final _searchProvider =
    NotifierProvider<_SearchNotifier, String>(_SearchNotifier.new);

class _SearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

// ── Horizon provider ─────────────────────────────────────────────────────────
final _horizonProvider = StateProvider<int>((ref) => 0); // 0=24h 1=48h 2=72h

// ── Main screen ──────────────────────────────────────────────────────────────
class RainfallForecastScreen extends ConsumerWidget {
  static const String route = '/rainfall-forecast';
  const RainfallForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = core_theme.RiverTheme.of(context).colors;
    final query = ref.watch(_searchProvider);
    final horizon = ref.watch(_horizonProvider);
    final allPreds = ref.watch(biharBulkPredictionsProvider);

    final preds = allPreds
        .where((p) =>
            query.isEmpty ||
            p.station.toLowerCase().contains(query.toLowerCase()) ||
            p.river.toLowerCase().contains(query.toLowerCase()))
        .toList()
      ..sort((a, b) => b.riskScore.compareTo(a.riskScore));

    final critical = preds.where((p) => p.severity == 'CRITICAL').length;

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: AppBar(
        backgroundColor: c.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(children: [
          Icon(Icons.grain_rounded, color: c.accent, size: 20),
          const SizedBox(width: 8),
          Text('Rainfall Forecast',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          if (critical > 0)
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF4D5A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            const Color(0xFFFF4D5A).withValues(alpha: 0.35))),
                child: Text('$critical critical',
                    style: const TextStyle(
                        color: Color(0xFFFF4D5A),
                        fontSize: 10,
                        fontWeight: FontWeight.w700))),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Material(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  onChanged: (v) => ref.read(_searchProvider.notifier).set(v),
                  style: TextStyle(color: c.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search station or river…',
                    hintStyle: TextStyle(color: c.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: c.textMuted, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.surfaceOutline)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.surfaceOutline)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.accent)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: c.cardBg,
                  ),
                ),
              ),
            ),
            // Horizon tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                _HorizonTab(
                    label: '24 Hours',
                    active: horizon == 0,
                    color: c.accent,
                    onTap: () => ref.read(_horizonProvider.notifier).state = 0),
                const SizedBox(width: 8),
                _HorizonTab(
                    label: '48 Hours',
                    active: horizon == 1,
                    color: c.accent,
                    onTap: () => ref.read(_horizonProvider.notifier).state = 1),
                const SizedBox(width: 8),
                _HorizonTab(
                    label: '72 Hours',
                    active: horizon == 2,
                    color: c.accent,
                    onTap: () => ref.read(_horizonProvider.notifier).state = 2),
                const Spacer(),
                Text('\${preds.length} stations',
                    style: TextStyle(color: c.textMuted, fontSize: 11)),
              ]),
            ),
          ]),
        ),
      ),
      body: preds.isEmpty
          ? _EmptyState(c: c, query: query)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: preds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) =>
                  _StationCard(pred: preds[i], horizon: horizon, c: c),
            ),
    );
  }
}

// -- Horizon tab --
class _HorizonTab extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _HorizonTab(
      {required this.label,
      required this.active,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active
                    ? color.withValues(alpha: 0.40)
                    : const Color(0xFF232934))),
        child: Text(label,
            style: TextStyle(
                color: active ? color : const Color(0xFF7A8290),
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

// -- Station card --
class _StationCard extends StatelessWidget {
  final FloodPrediction pred;
  final int horizon;
  final dynamic c;
  const _StationCard(
      {required this.pred, required this.horizon, required this.c});

  Color get _color {
    switch (pred.severity) {
      case 'CRITICAL':
        return const Color(0xFFFF4D5A);
      case 'SEVERE':
        return const Color(0xFFFF8C42);
      case 'MODERATE':
        return const Color(0xFFFFC857);
      default:
        return const Color(0xFF3ACC8A);
    }
  }

  double get _level {
    switch (horizon) {
      case 0:
        return pred.predicted24h;
      case 1:
        return pred.predicted48h;
      default:
        return pred.predicted72h;
    }
  }

  String get _horizonLabel {
    switch (horizon) {
      case 0:
        return 'in 24h';
      case 1:
        return 'in 48h';
      default:
        return 'in 72h';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final bar = (pred.riskScore / 100).clamp(0.0, 1.0);
    final name = pred.station.split(' (').first;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(context, '/city', arguments: name);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.water_rounded, color: color, size: 20)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text(pred.river,
                      style: TextStyle(color: c.textSecondary, fontSize: 11)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.35))),
                  child: Text(pred.severity,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5))),
              const SizedBox(height: 3),
              Text('Risk ${pred.riskScore.toStringAsFixed(0)}%',
                  style: TextStyle(color: c.textMuted, fontSize: 10)),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Text(_level.toStringAsFixed(2),
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(' m', style: TextStyle(color: c.textSecondary, fontSize: 14)),
            const SizedBox(width: 6),
            Text(_horizonLabel,
                style: TextStyle(color: c.textMuted, fontSize: 11)),
            const Spacer(),
            Row(children: [
              _MiniLevel(
                  label: '24h',
                  value: pred.predicted24h,
                  active: horizon == 0,
                  color: color,
                  c: c),
              const SizedBox(width: 4),
              _MiniLevel(
                  label: '48h',
                  value: pred.predicted48h,
                  active: horizon == 1,
                  color: color,
                  c: c),
              const SizedBox(width: 4),
              _MiniLevel(
                  label: '72h',
                  value: pred.predicted72h,
                  active: horizon == 2,
                  color: color,
                  c: c),
            ]),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: bar,
                  minHeight: 5,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color))),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Low', style: TextStyle(color: c.textMuted, fontSize: 9)),
            Text('Critical', style: TextStyle(color: c.textMuted, fontSize: 9)),
          ]),
        ]),
      ),
    );
  }
}

class _MiniLevel extends StatelessWidget {
  final String label;
  final double value;
  final bool active;
  final Color color;
  final dynamic c;
  const _MiniLevel(
      {required this.label,
      required this.value,
      required this.active,
      required this.color,
      required this.c});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color:
                  active ? color.withValues(alpha: 0.40) : c.surfaceOutline)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                color: active ? color : c.textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w600)),
        Text('${value.toStringAsFixed(1)}m',
            style: TextStyle(
                color: active ? color : c.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// -- Empty state --
class _EmptyState extends StatelessWidget {
  final dynamic c;
  final String query;
  const _EmptyState({required this.c, required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.grain_rounded, color: c.textMuted, size: 48),
        const SizedBox(height: 12),
        Text(
            query.isEmpty
                ? 'No forecast data available'
                : 'No stations match "$query"',
            style: TextStyle(color: c.textSecondary, fontSize: 15)),
        const SizedBox(height: 4),
        Text('Pull to refresh or check connection',
            style: TextStyle(color: c.textMuted, fontSize: 12)),
      ]),
    );
  }
}
