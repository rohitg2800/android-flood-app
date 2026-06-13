// lib/services/excel_export_service.dart
// OpsFlood — Excel Export Service
//
// Switched from syncfusion_flutter_xlsio to the pure-Dart `excel` package
// (^4.0.6) which has no analyzer version conflict with flutter_riverpod 3.x.
//
// Usage:
//   final bytes = await ExcelExportService.exportAlerts(alerts);
//   await ExcelExportService.saveAndShare(bytes, 'flood_alerts');

import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/alert_engine.dart';

class ExcelExportService {
  ExcelExportService._();

  // -------------------------------------------------------------------------
  // Export FloodAlerts to an Excel workbook in memory
  // -------------------------------------------------------------------------
  static Future<Uint8List> exportAlerts(List<FloodAlert> alerts) async {
    final excel = Excel.createExcel();
    final sheet = excel['Flood Alerts'];
    excel.delete('Sheet1'); // remove default blank sheet

    // Header row
    final headers = [
      'ID', 'Severity', 'Type', 'Title', 'Station',
      'River', 'District', 'State',
      'Current Level (m)', 'Threshold (m)',
      'Rate of Rise (m/h)', 'Rainfall 24h (mm)',
      'Issued At', 'Expires At', 'Action',
    ];
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1a3a5c'),
        fontColorHex: ExcelColor.fromHexString('#ffffff'),
      );
    }

    // Data rows
    for (var r = 0; r < alerts.length; r++) {
      final a = alerts[r];
      final row = r + 1;
      final values = [
        a.id,
        a.severity.name,
        a.type.name,
        a.title,
        a.stationName,
        a.river,
        a.district,
        a.state,
        a.currentLevel.toStringAsFixed(2),
        a.thresholdLevel.toStringAsFixed(2),
        a.rateOfRiseMph?.toStringAsFixed(3) ?? '-',
        a.rainfall24hMm?.toStringAsFixed(1) ?? '-',
        a.issuedAt.toIso8601String(),
        a.expiresAt?.toIso8601String() ?? '-',
        a.action,
      ];
      for (var c = 0; c < values.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
            .value = TextCellValue(values[c]);
      }
    }

    // Auto-fit column widths (approximate)
    for (var c = 0; c < headers.length; c++) {
      sheet.setColumnWidth(c, 20.0);
    }

    final encoded = excel.encode();
    if (encoded == null) throw Exception('Excel encode failed');
    return Uint8List.fromList(encoded);
  }

  // -------------------------------------------------------------------------
  // Save bytes to temp file and share via share_plus
  // -------------------------------------------------------------------------
  static Future<void> saveAndShare(
    Uint8List bytes,
    String fileNameWithoutExtension,
  ) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileNameWithoutExtension.xlsx');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.shareXFiles(
      [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: 'OpsFlood Export — $fileNameWithoutExtension',
    );
  }
}
