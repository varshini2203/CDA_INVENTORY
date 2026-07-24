// lib/services/excel_export_web.dart
//
// Web-only implementation: triggers a browser file download via a Blob +
// temporary anchor link. Only ever compiled in when targeting Flutter Web
// (selected by the conditional import in excel_export_service.dart).

import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveOrDownload(List<int> bytes, String filename) async {
  final blob = html.Blob(
    [Uint8List.fromList(bytes)],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}