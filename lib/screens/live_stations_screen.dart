// lib/screens/live_stations_screen.dart
// OpsFlood — LiveStationsScreen v1
// Lists live CWC river stations sorted by DangerClass (extreme → normal).
// Gauge bar fill + card border glow from RiverStation.dangerClass colours.
// Search filters by station / city / river name.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/river_station.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';

class LiveStationsScreen extends StatefulWidget {
  const LiveStationsScreen({super.key});
  @override
  State<LiveStationsScreen> createState() => _LiveStationsScreenState();
}

class _LiveStationsScreenState extends State<LiveStationsScreen> {
  final RealTimeService _svc = RealTimeService();
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onData);
    _search.addListener(() {
      setState(() => _query = _search.text.toLowerCase());
    });
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _svc.removeListener(_onData);
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await _svc.refreshData();
    if (mounted) setState(() => _refreshing = false);
  }

  List<RiverStation> get _filtered {
    final all = List<RiverStation>.from(_svc.stations)
      ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
    if (_query.isEmpty) return all;
    return all.where((s) =>
        s.station.toLowerCase().contains(_query) ||
        s.city.toLowerCase().contains(_query) ||
        s.river.toLowerCase().contains(_query)).toList();
  }

  // Map DangerClass to AppPalette colour.
  Color _dangerColor(DangerClass dc) {
    switch (dc) {
      case DangerClass.extreme:     return AppPalette.critical;
      case DangerClass.severe:      return AppPalette.danger;
      case DangerClass.aboveNormal: return AppPalette.warning;
      case DangerClass.normal:      return AppPalette.safe;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stations = _filtered;

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _searchBar(),
            Expanded(
              child: stations.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      color: AppPalette.cyan,
                      backgroundColor: AppPalette.abyss2,
                      onRefresh: _refresh,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: stations.length,
                        itemBuilder: (_, i) => _stationCard(stations[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: AppPalette.cyan.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppPalette.cyan.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppPalette.cyan.withValues(alpha: 0.28)),
          ),
          child: const Icon(Icons.sensors_rounded,
              color: AppPalette.cyan, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Live Stations',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: AppPalette.textWhite, letterSpacing: -0.4,
                  )),
              Text(
                '${_svc.stations.length} CWC stations',
                style: TextStyle(
                  fontSize: 10,
                  color: AppPalette.textGrey.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _refresh();
          },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppPalette.abyss2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.abyssStroke),
            ),
            child: _refreshing
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppPalette.cyan))
                : const Icon(Icons.refresh_rounded,
                    color: AppPalette.textGrey, size: 18),
          ),
        ),
      ],
    ),
  );

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: TextField(
      controller: _search,
      style: const TextStyle(
          color: AppPalette.textWhite, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search station, city or river…',
        hintStyle: TextStyle(
            color: AppPalette.textGrey.withValues(alpha: 0.5),
            fontSize: 12),
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppPalette.textGrey, size: 18),
        suffixIcon: _query.isNotEmpty
            ? GestureDetector(
                onTap: () => _search.clear(),
                child: const Icon(Icons.close_rounded,
                    color: AppPalette.textGrey, size: 16))
            : null,
        filled: true,
        fillColor: AppPalette.abyss2,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppPalette.abyssStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppPalette.abyssStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: AppPalette.cyan.withValues(alpha: 0.45)),
        ),
      ),
    ),
  );

  // ── Station card ──────────────────────────────────────────────────────────────
  Widget _stationCard(RiverStation s) {
    final dc    = s.dangerClass;
    final color = _dangerColor(dc);
    final pct   = s.progressPct;  // 0.0 – 1.0 of HFL

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppPalette.glassMorph(
        radius: 18,
        borderColor: color.withValues(alpha: 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: station name + tier badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.station,
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: AppPalette.textWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.river}  •  ${s.city}, ${s.state}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppPalette.textGrey
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _badge(dc.label.toUpperCase(), color),
                  if (s.isLive) ...[
                    const SizedBox(height: 4),
                    _badge('LIVE', AppPalette.safe),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: gauge levels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _levelCol('Current',
                  '${s.current.toStringAsFixed(2)} m', color),
              _levelCol('Warning',
                  '${s.warning.toStringAsFixed(1)} m',
                  AppPalette.warning),
              _levelCol('Danger',
                  '${s.danger.toStringAsFixed(1)} m',
                  AppPalette.critical),
              _levelCol('HFL',
                  '${s.hfl.toStringAsFixed(1)} m',
                  AppPalette.textGrey),
            ],
          ),

          const SizedBox(height: 10),

          // Gauge bar (progress toward HFL)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Level vs HFL',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppPalette.textGrey
                              .withValues(alpha: 0.7))),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor:
                      AppPalette.abyss4.withValues(alpha: 0.6),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Footer: trend + dataSource + flow
          Row(children: [
            if (s.trend != null)
              _trendChip(s.trend!),
            if (s.dataSource != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppPalette.cyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color:
                          AppPalette.cyan.withValues(alpha: 0.18)),
                ),
                child: Text(
                  s.dataSource!,
                  style: const TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w600,
                    color: AppPalette.cyan, letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (s.flowRate != null)
              Text(
                '${s.flowRate!.toStringAsFixed(0)} m³/s',
                style: TextStyle(
                  fontSize: 9,
                  color: AppPalette.textGrey.withValues(alpha: 0.7),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _emptyState() {
    final noStations = _svc.stations.isEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.cyan.withValues(alpha: 0.08),
              border: Border.all(
                  color: AppPalette.cyan.withValues(alpha: 0.18)),
            ),
            child: Icon(
              noStations
                  ? Icons.sensors_off_rounded
                  : Icons.search_off_rounded,
              color: AppPalette.cyan, size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            noStations
                ? 'Fetching station data…'
                : 'No stations match “$_query”',
            style: const TextStyle(
              color: AppPalette.textGrey,
              fontSize: 14, fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            noStations ? 'CWC  •  WRD  •  GloFAS' : 'Try a different search term',
            style: const TextStyle(
              color: AppPalette.textDim, fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ── Atoms ─────────────────────────────────────────────────────────────────────
  Widget _badge(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: c.withValues(alpha: 0.35)),
    ),
    child: Text(label,
        style: TextStyle(
            color: c, fontSize: 8, fontWeight: FontWeight.w800,
            letterSpacing: 0.4)),
  );

  Widget _levelCol(String label, String val, Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(val,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: c)),
      Text(label,
          style: const TextStyle(
              fontSize: 9, color: AppPalette.textGrey)),
    ],
  );

  Widget _trendChip(String trend) {
    final isRising  = trend.toLowerCase().contains('ris');
    final isFalling = trend.toLowerCase().contains('fall');
    final icon = isRising
        ? Icons.trending_up_rounded
        : isFalling
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;
    final color = isRising
        ? AppPalette.warning
        : isFalling
            ? AppPalette.safe
            : AppPalette.textGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(trend,
            style: TextStyle(
                fontSize: 8, fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }
}
