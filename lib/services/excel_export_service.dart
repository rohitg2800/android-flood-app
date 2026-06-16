// lib/services/excel_export_service.dart  v2
// Fixed:
//   • state/rateOfRiseMph/rainfall24hMm/expiresAt/action — use optional fields
//   • SharePlus → Share.shareXFiles (share_plus ^10)
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'alert_engine.dart';

class ExcelExportService {
  ExcelExportService._();
  static final ExcelExportService instance = ExcelExportService._();

  Future<void> exportAlerts(List<FloodAlert> alerts) async {
    final excel = Excel.createExcel();
    final sheet = excel['Alerts'];

    // Header row
    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Station'),
      TextCellValue('River'),
      TextCellValue('District'),
      TextCellValue('State'),
      TextCellValue('Severity'),
      TextCellValue('Type'),
      TextCellValue('Current Level (m)'),
      TextCellValue('Threshold Level (m)'),
      TextCellValue('Rate of Rise (m/h)'),
      TextCellValue('Rainfall 24h (mm)'),
      TextCellValue('Issued At'),
      TextCellValue('Expires At'),
      TextCellValue('Action'),
    ]);

    for (final a in alerts) {
      sheet.appendRow([
        TextCellValue(a.id),
        TextCellValue(a.stationName),
        TextCellValue(a.river),
        TextCellValue(a.district),
        TextCellValue(a.state ?? ''),
        TextCellValue(a.severity.label),
        TextCellValue(a.type.label),
        DoubleCellValue(a.currentLevel),
        DoubleCellValue(a.thresholdLevel),
        DoubleCellValue(a.rateOfRiseMph ?? 0),
        DoubleCellValue(a.rainfall24hMm ?? 0),
        TextCellValue(a.issuedAt.toIso8601String()),
        TextCellValue(a.expiresAt?.toIso8601String() ?? ''),
        TextCellValue(a.action ?? ''),
      ]);
    }

    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/opsflood_alerts.xlsx';
    final file = File(path);
    await file.writeAsBytes(excel.encode()!);

    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: 'OpsFlood Alert Export',
    );
  }
}
