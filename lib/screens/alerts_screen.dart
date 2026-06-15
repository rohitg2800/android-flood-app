// lib/screens/alerts_screen.dart  v3.0
//
// v3.0 (15 Jun 2026) — P0/P2/P3 fixes
//
//   P0: _AlertCard.alert typed dynamic → FloodAlert — eliminates _CastError crash.
//   P0: filter predicates use correct field names (stationName, not station).
//   P2: nav argument uses alert.district (city name), not alert.title.
//   P2: progress bar label now correctly shows DL vs WL based on alert.type.
//   P3: _PulseDot uses shared _PulseController (one AnimationController for
//       all visible dots instead of O(n) controllers).
//
//   v2.1 notification deep-link filter fully retained.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/alert_provider.dart';
import '../providers/alerts_provider.dart';
import '../app_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// P3: Shared pulse animation — one AnimationController for all _PulseDot widgets
//     on screen. Reduces concurrent tickers from O(alert count) to O(1).
// ─────────────────────────────────────────────────────────────────────────────
class _PulseController extends InheritedWidget {
  final Animation<double> scale;
  const _PulseController({required this.scale, required super.child});

  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PulseController>()?.scale;

  @override
  bool updateShouldNotify(_PulseController old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
class AlertsScreen extends ConsumerStatefulWidget {
  static const String route = Routes.alerts;

  /// When non-null (set by notification tap handler in main.dart),
  /// the screen pre-filters to show only alerts matching this station name.
  final String? stationFilter;

  const AlertsScreen({super.key, this.stationFilter});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';

  // P3: single shared pulse controller
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseScale;

  @override
  void initState() {
    super.initState();
    if (widget.stationFilter != null && widget.stationFilter!.isNotEmpty) {
      _searchQuery = widget.stationFilter!.toLowerCase();
    }
    _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── severity helpers ──────────────────────────────────────────────────────────
  static Color _severityColor(AlertSeverity s, RiverColors t) {
    switch (s) {
      case AlertSeverity.critical:
      case AlertSeverity.emergency:
        return const Color(0xFFFF1744);
      case AlertSeverity.warning:
        return const Color(0xFFFF6D00);
      default:
        return t.riverNormal;
    }
  }

  static IconData _severityIcon(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical:
      case AlertSeverity.emergency:
        return Icons.crisis_alert_rounded;
      case AlertSeverity.warning:
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  static String _severityLabel(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical:  return 'CRITICAL';
      case AlertSeverity.emergency: return 'EMERGENCY';
      case AlertSeverity.warning:   return 'WARNING';
      default:                      return s.name.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t  = RiverColors.of(context);
    final ap = ref.watch(alertProvider);

    // P0: access .stationName (correct field) not .station (non-existent)
    final allAlerts = ap.all;
    final alerts = _searchQuery.isEmpty
        ? allAlerts
        : allAlerts.where((a) =>
              a.stationName.toLowerCase().contains(_searchQuery) ||
              a.title.toLowerCase().contains(_searchQuery)       ||
              a.river.toLowerCase().contains(_searchQuery)       ||
              a.district.toLowerCase().contains(_searchQuery))
            .toList();

    final criticalCount = alerts.where((a) =>
        a.severity == AlertSeverity.critical ||
        a.severity == AlertSeverity.emergency).length;
    final warningCount  = alerts.where((a) =>
        a.severity == AlertSeverity.warning).length;
    final infoCount     = alerts.length - criticalCount - warningCount;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: _PulseController(
        scale: _pulseScale,
        child: CustomScrollView(
          slivers: [
            // ── App bar ───────────────────────────────────────────────────
            Td3AppBar(
              title: 'Flood Alerts',
              subtitle: _searchQuery.isNotEmpty
                  ? 'Showing: $_searchQuery  (${alerts.length} alert${alerts.length == 1 ? '' : 's'})'
                  : alerts.isEmpty
                      ? 'No active alerts'
                      : '${alerts.length} active  \u00b7  $criticalCount critical',
              actions: [
                if (_searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ActionChip(
                      label: Text(
                        '\u2715  $_searchQuery',
                        style: TextStyle(
                            color: t.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                      backgroundColor: t.accent.withOpacity(0.12),
                      side: BorderSide(color: t.accent.withOpacity(0.4)),
                      onPressed: () => setState(() => _searchQuery = ''),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.map_outlined, color: t.accent),
                  tooltip: 'Bihar Map',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(Routes.biharRiverMap),
                ),
              ],
            ),

            // ── KPI strip ─────────────────────────────────────────────────
            if (alerts.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      _KpiChip(
                        label: 'Critical',
                        count: criticalCount,
                        color: const Color(0xFFFF1744),
                        theme: t,
                      ),
                      const SizedBox(width: 8),
                      _KpiChip(
                        label: 'Warning',
                        count: warningCount,
                        color: const Color(0xFFFF6D00),
                        theme: t,
                      ),
                      const SizedBox(width: 8),
                      _KpiChip(
                        label: 'Info',
                        count: infoCount,
                        color: t.riverNormal,
                        theme: t,
                      ),
                    ],
                  ),
                ),
              ),

            // ── Empty state ────────────────────────────────────────────────
            if (alerts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  theme: t,
                  filterActive: _searchQuery.isNotEmpty,
                  stationName:  _searchQuery,
                  onClearFilter: () => setState(() => _searchQuery = ''),
                ),
              )

            // ── Alert cards ──────────────────────────────────────────────
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final a = alerts[i];
                      return _AlertCard(
                        alert:         a,
                        theme:         t,
                        severityColor: _severityColor(a.severity, t),
                        severityIcon:  _severityIcon(a.severity),
                        severityLabel: _severityLabel(a.severity),
                        // P2: use district (city name) not title for nav
                        onTap: () => Navigator.of(ctx).pushNamed(
                          Routes.cityDetail,
                          arguments: a.district,
                        ),
                      );
                    },
                    childCount: alerts.length,
                  ),
                ),
              ),
          ],
        ),
      ),

      // ── SOS FAB ───────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        heroTag:         'alerts_sos',
        backgroundColor: const Color(0xFFFF1744),
        foregroundColor: Colors.white,
        icon:  const Icon(Icons.sos_rounded),
        label: const Text('SOS',
            style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => Navigator.of(context).pushNamed(Routes.sos),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _KpiChip
// ─────────────────────────────────────────────────────────────────────────────
class _KpiChip extends StatelessWidget {
  final String    label;
  final int       count;
  final Color     color;
  final RiverColors theme;
  const _KpiChip({
    required this.label,
    required this.count,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count',
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AlertCard  — P0: typed FloodAlert (was dynamic)
// ─────────────────────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  // P0: was `dynamic alert` — now correctly typed
  final FloodAlert  alert;
  final RiverColors theme;
  final Color       severityColor;
  final IconData    severityIcon;
  final String      severityLabel;
  final VoidCallback onTap;

  const _AlertCard({
    required this.alert,
    required this.theme,
    required this.severityColor,
    required this.severityIcon,
    required this.severityLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;

    // P0: no more `as double` cast — fields are already double
    final lvl      = alert.currentLevel;
    final thr      = alert.thresholdLevel;
    final progress = thr > 0 ? (lvl / thr).clamp(0.0, 1.0) : 0.0;

    // P2: correct progress bar label (DL vs WL based on type)
    final thrLabel = (alert.type == AlertType.breach ||
            alert.thresholdLevel >= alert.dangerLevel * 0.85)
        ? 'DL'
        : 'WL';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: severityColor.withOpacity(0.25), width: 1),
            boxShadow: [
              BoxShadow(
                  color: severityColor.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Severity bar (left accent)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: severityColor,
                    borderRadius: const BorderRadius.only(
                      topLeft:    Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Title row
                        Row(
                          children: [
                            // P3: reads shared animation from InheritedWidget
                            _PulseDot(color: severityColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                alert.title,
                                style: TextStyle(
                                    color:      t.textPrimary,
                                    fontSize:   14,
                                    fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: severityColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: severityColor.withOpacity(0.5)),
                              ),
                              child: Text(severityLabel,
                                  style: TextStyle(
                                      color:      severityColor,
                                      fontSize:   9,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // River + level line
                        Text(
                          '${alert.river}  \u00b7  ${lvl.toStringAsFixed(2)} m'
                          '${alert.dangerLevel > 0 ? "  (DL ${alert.dangerLevel.toStringAsFixed(2)} m)" : ""}',
                          style:
                              TextStyle(color: t.textSecondary, fontSize: 12),
                        ),

                        const SizedBox(height: 8),

                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value:           progress,
                            minHeight:       5,
                            backgroundColor: severityColor.withOpacity(0.12),
                            valueColor:
                                AlwaysStoppedAnimation(severityColor),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Progress label + nav cue
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // P2: shows DL or WL correctly
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}% of $thrLabel',
                              style: TextStyle(
                                  color: t.textSecondary, fontSize: 10),
                            ),
                            Row(
                              children: [
                                Text('Details',
                                    style: TextStyle(
                                        color:      t.accent,
                                        fontSize:   10,
                                        fontWeight: FontWeight.w600)),
                                Icon(Icons.chevron_right_rounded,
                                    color: t.accent, size: 14),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// P3: _PulseDot reads shared Animation<double> from _PulseController
//     (InheritedWidget injected at screen level). Falls back to its own
//     scale=1.0 if somehow used outside the provider — safe by default.
// ─────────────────────────────────────────────────────────────────────────────
class _PulseDot extends StatelessWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  Widget build(BuildContext context) {
    // P3: read shared scale from InheritedWidget; fallback = static 1.0
    final scale = _PulseController.maybeOf(context);
    if (scale == null) {
      return _dot(1.0);
    }
    return AnimatedBuilder(
      animation: scale,
      builder: (_, __) => Transform.scale(
        scale: scale.value,
        child: _dot(1.0),
      ),
    );
  }

  Widget _dot(double _) => Container(
        width:  8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color:       color.withOpacity(0.5),
                blurRadius:  6,
                spreadRadius: 1),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final RiverColors  theme;
  final bool         filterActive;
  final String       stationName;
  final VoidCallback? onClearFilter;

  const _EmptyState({
    required this.theme,
    this.filterActive  = false,
    this.stationName   = '',
    this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:  t.riverNormal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              filterActive
                  ? Icons.search_off_rounded
                  : Icons.check_circle_outline_rounded,
              size:  56,
              color: t.riverNormal,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            filterActive
                ? 'No alerts for "$stationName"'
                : 'All Clear',
            style: TextStyle(
                color:      t.textPrimary,
                fontSize:   20,
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            filterActive
                ? 'This station has no active alerts right now.'
                : 'No active flood alerts at this time.',
            style:     TextStyle(color: t.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (filterActive && onClearFilter != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClearFilter,
              icon:  const Icon(Icons.clear_rounded),
              label: const Text('Show all alerts'),
              style: OutlinedButton.styleFrom(
                foregroundColor: t.accent,
                side: BorderSide(color: t.accent),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Levels are within safe ranges.',
              style: TextStyle(color: t.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
