// lib/screens/crowd_report_feed_screen.dart
// OpsFlood — Phase 8: Crowd Report Feed (reads incident_queue_v1 from SharedPreferences)
// v8.7-fix: Wrap AppBar title Row in Flexible to prevent 1.5px right overflow.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:equinox_flood/core/theme/river_theme.dart' as core_theme;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import 'incident_report_screen.dart'
    show IncidentDraft, IncidentType, IncidentTypeExt, SeverityExt;

class CrowdReportFeedScreen extends StatefulWidget {
  static const String route = '/crowd-report-feed';
  const CrowdReportFeedScreen({super.key});

  @override
  State<CrowdReportFeedScreen> createState() => _CrowdReportFeedScreenState();
}

class _CrowdReportFeedScreenState extends State<CrowdReportFeedScreen> {
  List<IncidentDraft> _reports = [];
  bool _loading = true;
  String _filterDistrict = 'All';
  IncidentType? _filterType;

  static const String _queueKey = 'incident_queue_v1';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_queueKey) ?? [];
      final parsed = raw
          .map((s) {
            try {
              return IncidentDraft.fromJson(
                  jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<IncidentDraft>()
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _reports = parsed;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteReport(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? [];
    final target = _reports[index];
    raw.removeWhere((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return m['createdAt'] == target.createdAt.toIso8601String();
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_queueKey, raw);
    await _load();
  }

  List<IncidentDraft> get _filtered {
    return _reports.where((r) {
      final districtOk =
          _filterDistrict == 'All' || r.district == _filterDistrict;
      final typeOk = _filterType == null || r.type == _filterType;
      return districtOk && typeOk;
    }).toList();
  }

  Set<String> get _districts {
    final d =
        _reports.map((r) => r.district).where((d) => d.isNotEmpty).toSet();
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF05070A),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFFF5F7FA),
        // v8.7-fix: title uses Row inside Flexible so it never exceeds _AppBarTitleBox width.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.feed, color: Colors.deepOrange, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: const Text(
                'Community Reports',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            if (!_loading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.deepOrange.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${filtered.length}',
                  style: const TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'New Report',
            onPressed: () => Navigator.pushNamed(context, '/incident-report')
                .then((_) => _load()),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(t),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmpty(t)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, i) => _ReportCard(
                            draft: filtered[i],
                            theme: t,
                            onDelete: () {
                              final idx = _reports.indexOf(filtered[i]);
                              if (idx >= 0) _deleteReport(idx);
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Report Incident'),
        onPressed: () => Navigator.pushNamed(context, '/incident-report')
            .then((_) => _load()),
      ),
    );
  }

  Widget _buildFilterBar(RiverColors t) {
    return Container(
      color: t.navBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: _filterDistrict,
              icon: Icons.location_on_outlined,
              theme: t,
              onTap: () => _showDistrictPicker(t),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: _filterType?.label ?? 'All Types',
              icon: Icons.filter_list,
              theme: t,
              onTap: () => _showTypePicker(t),
            ),
            if (_filterDistrict != 'All' || _filterType != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _filterDistrict = 'All';
                  _filterType = null;
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.clear, size: 13, color: Colors.red),
                      SizedBox(width: 4),
                      Text('Clear',
                          style: TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDistrictPicker(RiverColors t) {
    final districts = ['All', ..._districts.toList()..sort()];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.navBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const SizedBox(height: 8),
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: t.divider,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          ...districts.map((d) => ListTile(
                title: Text(d,
                    style: TextStyle(color: t.textPrimary, fontSize: 14)),
                trailing: _filterDistrict == d
                    ? Icon(Icons.check, color: t.accent)
                    : null,
                onTap: () {
                  setState(() => _filterDistrict = d);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showTypePicker(RiverColors t) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.navBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const SizedBox(height: 8),
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: t.divider,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.all_inclusive),
            title: Text('All Types', style: TextStyle(color: t.textPrimary)),
            trailing:
                _filterType == null ? Icon(Icons.check, color: t.accent) : null,
            onTap: () {
              setState(() => _filterType = null);
              Navigator.pop(context);
            },
          ),
          ...IncidentType.values.map((type) => ListTile(
                leading: Icon(type.icon, color: type.color, size: 20),
                title: Text(type.label,
                    style: TextStyle(color: t.textPrimary, fontSize: 14)),
                trailing: _filterType == type
                    ? Icon(Icons.check, color: t.accent)
                    : null,
                onTap: () {
                  setState(() => _filterType = type);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmpty(RiverColors t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: t.textSecondary),
            const SizedBox(height: 16),
            Text(
              _filterDistrict != 'All' || _filterType != null
                  ? 'No reports match your filters'
                  : 'No community reports yet',
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to submit the first incident report from your area.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report card
// ─────────────────────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final IncidentDraft draft;
  final RiverColors theme;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.draft,
    required this.theme,
    required this.onDelete,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final type = draft.type;
    final sev = draft.severity;
    return Td3Card(
      showGloss: false,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (type?.color ?? Colors.grey).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: (type?.color ?? Colors.grey)
                            .withValues(alpha: 0.5)),
                  ),
                  child: Icon(type?.icon ?? Icons.report_problem,
                      color: type?.color ?? Colors.grey, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type?.label ?? 'Unknown',
                        style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _timeAgo(draft.createdAt),
                        style: TextStyle(color: t.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sev.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sev.color.withValues(alpha: 0.5), width: 1),
                  ),
                  child: Text(
                    sev.label,
                    style: TextStyle(
                        color: sev.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: t.textSecondary),
                  tooltip: 'Remove',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: t.navBg,
                      title: Text('Delete Report',
                          style: TextStyle(color: t.textPrimary)),
                      content: Text('Remove this report from the local queue?',
                          style: TextStyle(color: t.textSecondary)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel',
                              style: TextStyle(color: t.textSecondary)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onDelete();
                          },
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (draft.district.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 13, color: t.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    [
                      draft.district,
                      if (draft.block.isNotEmpty) draft.block,
                      if (draft.village.isNotEmpty) draft.village,
                    ].join(' › '),
                    style: TextStyle(color: t.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
            if (draft.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                draft.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: t.textPrimary.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (draft.lat != null) ...[
                  const Icon(Icons.my_location, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  const Text('GPS',
                      style: TextStyle(color: Colors.green, fontSize: 11)),
                  const SizedBox(width: 12),
                ],
                if (draft.photoCount > 0) ...[
                  Icon(Icons.photo_outlined, size: 12, color: t.textSecondary),
                  const SizedBox(width: 4),
                  Text('${draft.photoCount} photo(s)',
                      style: TextStyle(color: t.textSecondary, fontSize: 11)),
                  const SizedBox(width: 12),
                ],
                if (draft.reporterName.isNotEmpty) ...[
                  Icon(Icons.person_outline, size: 12, color: t.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      draft.reporterName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: t.textSecondary, fontSize: 11),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text('Anonymous',
                        style: TextStyle(color: t.textSecondary, fontSize: 11)),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'Pending sync',
                    style: TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final RiverColors theme;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.divider.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: t.textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: t.textSecondary),
          ],
        ),
      ),
    );
  }
}
