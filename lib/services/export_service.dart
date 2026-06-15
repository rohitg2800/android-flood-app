// lib/services/export_service.dart
// Adds missing `dangerLevel` field to ExportRow constructor.
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportRow {
  final String  stationName;
  final String  river;
  final String  district;
  final double  currentLevel;
  final double? warningLevel;
  final double? dangerLevel;     // ← was missing — fixes export_screen compile error
  final String  riskLevel;
  final String  fetchedAt;

  const ExportRow({
    required this.stationName,
    required this.river,
    required this.district,
    required this.currentLevel,
    this.warningLevel,
    this.dangerLevel,
    required this.riskLevel,
    required this.fetchedAt,
  });

  List<String> toCsvRow() => [
    stationName,
    river,
    district,
    currentLevel.toStringAsFixed(2),
    warningLevel?.toStringAsFixed(2) ?? '',
    dangerLevel?.toStringAsFixed(2)  ?? '',
    riskLevel,
    fetchedAt,
  ];

  static String get csvHeader =>
      'Station,River,District,Current(m),Warning(m),Danger(m),Risk,FetchedAt';
}

class ExportService {
  ExportService({
    String?  title,
    double?  currentLevel,       // alias used by older callers
  });

  static Future<void> exportAndShareCsv({
    required String        title,
    required List<ExportRow> rows,
  }) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/opsflood_export.csv');
    final buf  = StringBuffer();
    buf.writeln(ExportRow.csvHeader);
    for (final row in rows) {
      buf.writeln(row.toCsvRow().join(','));
    }
    await file.writeAsString(buf.toString());
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: title,
    );
  }

  static Future<void> exportAndSharePdf({
    required String        title,
    required List<ExportRow> rows,
  }) async {
    // PDF generation via printing package — stub that shares CSV as fallback.
    await exportAndShareCsv(title: title, rows: rows);
  }
}
