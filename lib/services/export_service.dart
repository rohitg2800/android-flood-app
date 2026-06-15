// lib/services/export_service.dart
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'alert_engine.dart';

class ExportRow {
  final String        stationName;
  final String        river;
  final String        district;
  final double        current;       // currentLevel
  final double        warning;
  final double        danger;
  final double        hfl;
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

  // Alias getter so callers using .currentLevel still compile
  double get currentLevel => current;
}

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  Future<File> exportCsv(List<ExportRow> rows, {String? filename}) async {
    final dir  = await getApplicationDocumentsDirectory();
    final name = filename ??
        'opsflood_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${dir.path}/$name');
    final data = [
      ['Station','River','District','Current (m)','Warning (m)','Danger (m)','HFL (m)','Severity'],
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

  /// Returns the file path so callers can store it (e.g. setState(() => _lastFilePath = path))
  Future<String> exportAndShareCsv(List<ExportRow> rows,
      {String? filename}) async {
    final file = await exportCsv(rows, filename: filename);
    await Share.shareXFiles([XFile(file.path)],
        text: 'OpsFlood CSV Export');
    return file.path;
  }

  Future<String> exportAndSharePdf(
    List<ExportRow> rows, {
    String? title,
    String? reportTitle,   // alias
    String? filename,
  }) async {
    // PDF library not yet integrated — fallback to CSV share.
    return exportAndShareCsv(rows, filename: filename);
  }
}
