// lib/services/export_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'alert_engine.dart';   // AlertSeverity

class ExportRow {
  final String         stationName;
  final String         river;
  final String         district;
  final double         currentLevel;
  final double?        warning;     // callers use warning: not warningLevel:
  final double?        danger;      // callers use danger:  not dangerLevel:
  final double?        hfl;
  final AlertSeverity? severity;
  final String         riskLevel;
  final String         fetchedAt;

  const ExportRow({
    required this.stationName,
    required this.river,
    required this.district,
    required this.currentLevel,
    this.warning,
    this.danger,
    this.hfl,
    this.severity,
    String? riskLevel,
    String? fetchedAt,
  })  : riskLevel = riskLevel ?? '',
        fetchedAt = fetchedAt ?? '';

  // Back-compat aliases so older callers using dangerLevel:/warningLevel: also work.
  double? get dangerLevel  => danger;
  double? get warningLevel => warning;

  List<String> toCsvRow() => [
    stationName,
    river,
    district,
    currentLevel.toStringAsFixed(2),
    warning?.toStringAsFixed(2) ?? '',
    danger?.toStringAsFixed(2)  ?? '',
    hfl?.toStringAsFixed(2)     ?? '',
    severity?.label ?? riskLevel,
    fetchedAt,
  ];

  static String get csvHeader =>
      'Station,River,District,Current(m),Warning(m),Danger(m),HFL(m),Risk,FetchedAt';
}

class ExportService {
  ExportService._();

  /// Singleton — used by export_screen.dart as ExportService.instance.
  static final ExportService instance = ExportService._();

  Future<String?> exportAndShareCsv(List<ExportRow> rows, {
    String title = 'OpsFlood Export',
  }) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/opsflood_export.csv');
    final buf  = StringBuffer();
    buf.writeln(ExportRow.csvHeader);
    for (final row in rows) {
      buf.writeln(row.toCsvRow().join(','));
    }
    await file.writeAsString(buf.toString());
    await Share.shareXFiles([XFile(file.path)], subject: title);
    return file.path;
  }

  Future<String?> exportAndSharePdf(List<ExportRow> rows, {
    String reportTitle = 'OpsFlood Report',
  }) async {
    // PDF stub — falls back to CSV share until pdf package is wired.
    return exportAndShareCsv(rows, title: reportTitle);
  }

  // Static variants kept for callers using ExportService.exportAndShareCsv()
  static Future<void> exportAndShareCsvStatic({
    required String          title,
    required List<ExportRow> rows,
  }) => ExportService.instance.exportAndShareCsv(rows, title: title);

  static Future<void> exportAndSharePdfStatic({
    required String          title,
    required List<ExportRow> rows,
  }) => ExportService.instance.exportAndSharePdf(rows, reportTitle: title);
}
