// lib/services/excel_export_io.dart
//
// Non-web implementation: writes the workbook to a temp file, then opens
// the native share sheet so the user can save it to Files/Drive/email/etc.
// Only ever compiled in on Android, iOS, and Desktop (selected by the
// conditional import in excel_export_service.dart).

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveOrDownload(List<int> bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(Uint8List.fromList(bytes));

  await Share.shareXFiles(
    [XFile(file.path,
        mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
    text: filename,
  );
}