// lib/services/csv_export_io.dart
//
// Non-web implementation for CSV downloads: writes the CSV text to a temp
// file, then opens the native share sheet so the user can save it to
// Files/Drive/email/etc. Mirrors excel_export_io.dart exactly — only ever
// compiled in on Android, iOS, and Desktop (selected by the conditional
// import in csv_export_service.dart).

import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveOrDownloadCsv(String csvContent, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  // UTF-8 BOM so Excel on Windows opens the file with correct encoding
  // instead of mangling non-ASCII characters.
  const bom = '\uFEFF';
  await file.writeAsBytes(utf8.encode('$bom$csvContent'));

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    text: filename,
  );
}