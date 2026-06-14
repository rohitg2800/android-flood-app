// lib/screens/alerts_screen.dart  v2.1
//
// v2.1 (14 Jun 2026) — Notification deep-link filter
//
//   Changes:
//     • Converted ConsumerWidget → ConsumerStatefulWidget
//     • Added optional `stationFilter` constructor param
//     • When opened from a notification tap, auto-filters to that station
//     • v2.0 UI fully retained (KPI strip, cards, SOS FAB, empty state)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/alert_provider.dart';
import '../providers/alerts_provider.dart';
import '../app_router.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  static const String route = Routes.alerts;

  /// When non-null (set by notification tap handler in main.dart),
  /// the screen pre-filters to show only alerts matching this station name.
  final String? stationFilter;

  const AlertsScreen({super.key, this.stationFilter});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Pre-populate search when opened from a notification
    if (widget.stationFilter != null && widget.stationFilter!.isNotEmpty) {
      _searchQuery = widget.stationFilter!.toLowerCase();
    }
  }

  // ── severity palette ───────────────────────────────────────────────────────
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
    final t      = RiverColors.of(context);
    final ap     = ref.watch(alertProvider);

    // Apply station filter when coming from notification tap
    final allAlerts = ap.all;
    final alerts = _searchQuery.isEmpty
        ? allAlerts
        : allAlerts
            .where((a) =>
                (a.station as String).toLowerCase().contains(_searchQuery) ||
                (a.title   as String).toLowerCase().contains(_searchQuery) ||
                (a.river   as String).toLowerCase().contains(_searchQuery))
            .toList();

    final criticalCount = alerts.where((a) =>
        a.severity == AlertSeverity.critical ||
        a.severity == AlertSeverity.emergency).length;
    final warningCount  = alerts.where((a) =>
        a.severity == AlertSeverity.warning).length;
    final infoCount     = alerts.length - criticalCount - warningCount;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────
          Td3AppBar(
            title: 'Flood Alerts',
            subtitle: _searchQuery.isNotEmpty
                ? 'Showing: $_searchQuery  (${alerts.length} alert${alerts.length == 1 ? '' : 's'})'
                : alerts.isEmpty
                    ? 'No active alerts'
                    : '${alerts.length} active  ·  $criticalCount critical',
            actions: [
              // Clear filter chip when filtering from notification
              if (_searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ActionChip(
                    label: Text(
                      '✕  $_searchQuery',
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

          // ── KPI strip ────────────────────────────────────────────────────
          if (alerts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 8, 12, 0),
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

          // ── Empty state ──────────────────────────────────────────────────
          if (alerts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                theme: t,
                filterActive: _searchQuery.isNotEmpty,
                stationName: _searchQuery,
                onClearFilter: () => setState(() => _searchQuery = ''),
              ),
            )

          // ── Alert cards ──────────────────────────────────────────────────
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _AlertCard(
                    alert: alerts[i],
                    theme: t,
                    severityColor: _severityColor(alerts[i].severity, t),
                    severityIcon:  _severityIcon(alerts[i].severity),
                    severityLabel: _severityLabel(alerts[i].severity),
                    onTap: () => Navigator.of(ctx).pushNamed(
                      Routes.cityDetail,
                      arguments: alerts[i].title,
                    ),
                  ),
                  childCount: alerts.length,
                ),
              ),
            ),
        ],
      ),

      // ── SOS FAB ────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'alerts_sos',
        backgroundColor: const Color(0xFFFF1744),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.sos_rounded),
        label: const Text('SOS',
            style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => Navigator.of(context).pushNamed(Routes.sos),
      ),
    );
  }
}

// ── KPI chip ──────────────────────────────────────────────────────────────────
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
        padding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Alert card ────────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final dynamic     alert;
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
    final t         = theme;
    final lvl       = alert.currentLevel as double;
    final dl        = alert.thresholdLevel as double;
    final progress  = dl > 0 ? (lvl / dl).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: severityColor.withOpacity(0.25), width: 1),
            boxShadow: [
              BoxShadow(
                color: severityColor.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Severity bar (left)
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
                // ── Content
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          children: [
                            _PulseDot(color: severityColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                alert.title as String,
                                style: TextStyle(
                                    color: t.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    severityColor.withOpacity(0.15),
                                borderRadius:
                                    BorderRadius.circular(6),
                                border: Border.all(
                                    color: severityColor
                                        .withOpacity(0.5)),
                              ),
                              child: Text(
                                severityLabel,
                                style: TextStyle(
                                    color: severityColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${alert.river}  ·  ${lvl.toStringAsFixed(2)} m'
                          '${dl > 0 ? "  (DL ${dl.toStringAsFixed(2)} m)" : ""}',
                          style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor:
                                severityColor.withOpacity(0.12),
                            valueColor:
                                AlwaysStoppedAnimation(severityColor),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}% of DL',
                              style: TextStyle(
                                  color: t.textSecondary,
                                  fontSize: 10),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Details',
                                  style: TextStyle(
                                      color: t.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600),
                                ),
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

// ── Animated pulse dot ────────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double>    _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: widget.color.withOpacity(0.5),
                blurRadius: 6,
                spreadRadius: 1)
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final RiverColors theme;
  final bool        filterActive;
  final String      stationName;
  final VoidCallback? onClearFilter;

  const _EmptyState({
    required this.theme,
    this.filterActive = false,
    this.stationName  = '',
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
              color: t.riverNormal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              filterActive
                  ? Icons.search_off_rounded
                  : Icons.check_circle_outline_rounded,
              size: 56,
              color: t.riverNormal,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            filterActive ? 'No alerts for "$stationName"' : 'All Clear',
            style: TextStyle(
                color: t.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            filterActive
                ? 'This station has no active alerts right now.'
                : 'No active flood alerts at this time.',
            style: TextStyle(color: t.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (filterActive && onClearFilter != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClearFilter,
              icon: const Icon(Icons.clear_rounded),
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
              style:
                  TextStyle(color: t.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
