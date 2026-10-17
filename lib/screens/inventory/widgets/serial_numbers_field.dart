// lib/screens/inventory/widgets/serial_numbers_field.dart
//
// Shared "Serial Number(s)" input for the Add / Edit Product screens.
//   - Type one serial per line (commas also work), or tap the scan icon to
//     scan a barcode / QR and append it as a new line.
//   - parseSerials() turns the raw text into a clean, de-duplicated list.

import 'package:flutter/material.dart';
import '../../../widgets/common/serial_scan_screen.dart';

/// "SN1, SN2\nSN3" -> ['SN1', 'SN2', 'SN3'] (trimmed, no blanks, no repeats).
List<String> parseSerials(String raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final part in raw.split(RegExp(r'[\n,;]'))) {
    final s = part.trim();
    if (s.isEmpty) continue;
    if (seen.add(s.toLowerCase())) out.add(s);
  }
  return out;
}

class SerialNumbersField extends StatelessWidget {
  final TextEditingController controller;
  // Read at validation time, so it always reflects what is typed right now.
  final TextEditingController quantityController;
  const SerialNumbersField(
      {super.key, required this.controller, required this.quantityController});

  Future<void> _scan(BuildContext context) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SerialScanScreen(title: 'Scan Serial Number')),
    );
    if (code == null || code.trim().isEmpty) return;
    final existing = controller.text.trimRight();
    controller.text = existing.isEmpty ? code.trim() : '$existing\n${code.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.multiline,
      minLines: 1,
      maxLines: 5,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Serial Number(s) (optional)',
        hintText: 'One per line — e.g. SN-0001',
        helperText: 'Use a new line for each unit',
        labelStyle: TextStyle(color: Colors.grey.shade600),
        floatingLabelStyle: const TextStyle(color: Color(0xFF1565C0)),
        prefixIcon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF1565C0), size: 20),
        suffixIcon: IconButton(
          tooltip: 'Scan serial',
          icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF1565C0)),
          onPressed: () => _scan(context),
        ),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      validator: (v) {
        final n = parseSerials(v ?? '').length;
        final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
        if (n > quantity) {
          return '$n serial numbers entered but quantity is $quantity';
        }
        return null;
      },
    );
  }
}