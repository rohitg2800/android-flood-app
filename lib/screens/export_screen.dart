// lib/screens/export_screen.dart
// OpsFlood — Module 6: Media, Image Attachments & Export
//
// ExportScreen
// ─────────────────────────────────────────────────────────────────────────
// Station data export UI — reachable via Settings → Export Data
// or via the action menu on any station list/detail screen.
//
// Features:
//   • Export to CSV (UTF-8 BOM, Excel compatible)
//   • Export to PDF (multi-page A4 landscape with severity colouring)
//   • Date range picker to filter readings
//   • Station count badge
//   • Progress indicator while building file
//   • Shares via OS share-sheet after generation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/export_service.dart';
import '../services/alert_engine.dart';   // AlertSeverity
import '../theme/river_theme.dart';
import '../widgets/ops_icon.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});
  static const String route = '/export';

  @override
  ConsumerState<ExportScreen> createState() =>
      _ExportScreenState();
}

class _ExportScreenState
    extends ConsumerState<ExportScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end:   DateTime.now(),
  );
  bool _exportingCsv = false;
  bool _exportingPdf = false;
  String? _lastFilePath;

  // Placeholder data — in production wire this to
  // DataFetchEngine / StationHistoryStore providers.
  List<ExportRow> get _rows => _buildDemoRows();

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.bgBase,
      appBar: AppBar(
        backgroundColor: t.navBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: t.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            OpsIcon(OpsIcons.export, size: 18, color: t.accent),
            const SizedBox(width: 8),
            Text(
              'Export Data',
              style: TextStyle(
                color: t.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ─ Date range picker card
          _SectionCard(
            t: t,
            title: 'Date Range',
            icon: Icons.date_range_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_fmtDate(_range.start)}  →  ${_fmtDate(_range.end)}',
                  style: TextStyle(
                      color: t.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.textPrimary,
                      side: BorderSide(color: t.stroke),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10),
                    ),
                    icon: Icon(Icons.edit_calendar_rounded,
                        color: t.accent, size: 16),
                    label: const Text('Change Range'),
                    onPressed: _pickDateRange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─ Station count info
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: t.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.sensors_rounded,
                    color: t.accent, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_rows.length} station readings ready for export',
                  style: TextStyle(
                      color: t.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─ CSV card
          _ExportActionCard(
            t:           t,
            icon:        Icons.table_chart_rounded,
            iconColor:   const AppPalette.safe,
            title:       'Export as CSV',
            subtitle:    'UTF-8 BOM • Excel compatible • RFC-4180',
            buttonLabel: 'Generate CSV',
            loading:     _exportingCsv,
            onTap:       _exportCsv,
          ),
          const SizedBox(height: 12),

          // ─ PDF card
          _ExportActionCard(
            t:           t,
            icon:        Icons.picture_as_pdf_rounded,
            iconColor:   const AppPalette.critical,
            title:       'Export as PDF',
            subtitle:
                'A4 landscape • Severity colour coding • Multi-page',
            buttonLabel: 'Generate PDF',
            loading:     _exportingPdf,
            onTap:       _exportPdf,
          ),

          // ─ Last exported file
          if (_lastFilePath != null) ...
            [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.stroke),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: AppPalette.safe, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Last export: ${_lastFilePath!.split('/').last}',
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> _exportCsv() async {
    setState(() => _exportingCsv = true);
    try {
      final path = await ExportService.instance
          .exportAndShareCsv(_rows);
      if (mounted) setState(() => _lastFilePath = path);
    } catch (e) {
      if (context.mounted) {
        _showError('CSV export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exportingPdf = true);
    try {
      final path = await ExportService.instance
          .exportAndSharePdf(
            _rows,
            reportTitle:
                'OpsFlood Bihar Flood Report  '
                '${_fmtDate(_range.start)}–${_fmtDate(_range.end)}',
          );
      if (mounted) setState(() => _lastFilePath = path);
    } catch (e) {
      if (context.mounted) _showError('PDF export failed: $e');
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _pickDateRange() async {
    final t = RiverColors.of(context);
    final picked = await showDateRangePicker(
      context:        context,
      firstDate:      DateTime(2020),
      lastDate:       DateTime.now(),
      initialDateRange: _range,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: t.accent,
            onPrimary: Colors.black,
            surface: t.cardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _range = picked);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppPalette.critical,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Demo data — replace with real provider ─────────────────────────────

  List<ExportRow> _buildDemoRows() {
    final stations = [
      ('Birpur',         'Kosi',          'Supaul',    75.92,  76.02, 74.50, 76.80,  AlertSeverity.critical),
      ('Baltara',        'Gandak',        'Muzaffarpur', 58.20, 59.10, 57.80, 59.80, AlertSeverity.warning),
      ('Hajipur',        'Gandak',        'Vaishali',  51.80,  53.20, 51.00, 54.00,  AlertSeverity.info),
      ('Rosera',         'Bagmati',       'Samastipur', 47.30, 48.60, 46.80, 49.20, AlertSeverity.warning),
      ('Dalsinghsarai',  'Buri Gandak',   'Samastipur', 39.10, 39.80, 38.50, 40.20, AlertSeverity.emergency),
      ('Muzaffarpur',    'Burhi Gandak',  'Muzaffarpur', 46.80, 48.20, 46.00, 49.00, null),
      ('Sitamarhi',      'Bagmati',       'Sitamarhi',  38.90, 40.10, 38.20, 41.00,  null),
      ('Supaul',         'Kosi',          'Supaul',    73.40,  76.02, 74.50, 76.80,  null),
    ];
    final now = DateTime.now();
    return stations.map((s) => ExportRow(
      stationName:  s.$1,
      river:        s.$2,
      district:     s.$3,
      currentLevel: s.$4,
      dangerLevel:  s.$5,
      warningLevel: s.$6,
      hfl:          s.$7,
      severity:     s.$8,
      observedAt:   now,
    )).toList();
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.year}';
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final RiverColors t;
  final String      title;
  final IconData    icon;
  final Widget      child;
  const _SectionCard({
    required this.t,
    required this.title,
    required this.icon,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: t.accent, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _ExportActionCard extends StatelessWidget {
  final RiverColors t;
  final IconData    icon;
  final Color       iconColor;
  final String      title;
  final String      subtitle;
  final String      buttonLabel;
  final bool        loading;
  final VoidCallback onTap;
  const _ExportActionCard({
    required this.t,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.loading,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10)),
                ),
                onPressed: loading ? null : onTap,
                child: loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                    : Text(
                        buttonLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
}
