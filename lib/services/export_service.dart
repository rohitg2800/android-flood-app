// lib/services/export_service.dart
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'alert_engine.dart';

class ExportRow {
  final String       stationName;   // was 'station' — renamed to match callers
  final String       river;
  final String       district;
  final double       current;
  final double       warning;
  final double       danger;
  final double       hfl;
  final AlertSeverity? severity;

  const ExportRow({
    required this.stationName,
    required this.river,
    required this.district,
    required this.current,
    required this.warning,
    required this.danger,
    required this.hfl,
    this.severity,
  });
}

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  // ── CSV ────────────────────────────────────────────────
  Future<File> exportCsv(List<ExportRow> rows, {String? filename}) async {
    final dir  = await getApplicationDocumentsDirectory();
    final name = filename ??
        'opsflood_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${dir.path}/$name');
    final data = [
      [
        'Station', 'River', 'District',
        'Current (m)', 'Warning (m)', 'Danger (m)', 'HFL (m)', 'Severity'
      ],
      ...rows.map((r) => [
        r.stationName, r.river, r.district,
        r.current.toStringAsFixed(2),
        r.warning.toStringAsFixed(2),
        r.danger.toStringAsFixed(2),
        r.hfl.toStringAsFixed(2),
        r.severity?.label ?? 'N/A',
      ]),
    ];
    await file.writeAsString(const ListToCsvConverter().convert(data));
    return file;
  }

  Future<void> exportAndShareCsv(List<ExportRow> rows,
      {String? filename}) async {
    final file = await exportCsv(rows, filename: filename);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
  }

  // ── PDF (stub — extend with pdf package as needed) ─────────────────
  Future<void> exportAndSharePdf(
    List<ExportRow> rows, {
    String? title,
    String? filename,
  }) async {
    // For now fall back to CSV until a PDF library is integrated.
    await exportAndShareCsv(rows, filename: filename);
  }
}
