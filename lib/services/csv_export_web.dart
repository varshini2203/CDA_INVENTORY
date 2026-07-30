// lib/services/csv_export_web.dart
//
// Web-only implementation for CSV downloads: triggers a browser file
// download via a Blob + temporary anchor link. Mirrors excel_export_web.dart
// exactly — only ever compiled in when targeting Flutter Web (selected by
// the conditional import in csv_export_service.dart).

import 'dart:html' as html;
import 'dart:convert';

Future<void> saveOrDownloadCsv(String csvContent, String filename) async {
  const bom = '\uFEFF';
  final bytes = utf8.encode('$bom$csvContent');
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}