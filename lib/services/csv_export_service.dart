// lib/services/csv_export_service.dart
//
// Minimal CSV builder + cross-platform download, following the exact same
// conditional-import pattern already used by ExcelExportService /
// excel_export_io.dart / excel_export_web.dart. Kept deliberately generic
// (List<List<Object?>> rows -> CSV string -> download) so any module can
// reuse it, not just Inventory Bulk Operations.

import 'csv_export_io.dart' if (dart.library.html) 'csv_export_web.dart' as platform;

class CsvExportService {
  CsvExportService._();

  /// Turns [headers] + [rows] into a single RFC-4180-ish CSV string.
  /// Any field containing a comma, quote, or newline is wrapped in quotes,
  /// with internal quotes doubled — the same escaping every spreadsheet
  /// app expects.
  static String build({
    required List<String> headers,
    required List<List<Object?>> rows,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escape).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_escape).join(','));
    }
    return buffer.toString();
  }

  static String _escape(Object? value) {
    final text = value?.toString() ?? '';
    final needsQuoting =
        text.contains(',') || text.contains('"') || text.contains('\n') || text.contains('\r');
    if (!needsQuoting) return text;
    return '"${text.replaceAll('"', '""')}"';
  }

  /// On Web: triggers a browser file download.
  /// On Android/iOS/Desktop: saves to a temp file and opens the share sheet.
  static Future<void> download(String csvContent, String filename) {
    return platform.saveOrDownloadCsv(csvContent, filename);
  }
}