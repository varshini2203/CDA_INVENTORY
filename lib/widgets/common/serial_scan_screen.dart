// lib/widgets/common/serial_scan_screen.dart
//
// Reusable full-screen camera scanner for product serial numbers / UIDs
// (and any other barcode/QR code in the app). Pops with the scanned
// string via Navigator.pop(context, code) — callers just await the
// pushed route:
//
//   final code = await Navigator.push<String>(
//     context,
//     MaterialPageRoute(builder: (_) => const SerialScanScreen()),
//   );
//   if (code != null) { ... look the product up by serial ... }
//
// Requires the `mobile_scanner` package — see setup note at the bottom
// of this file.

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SerialScanScreen extends StatefulWidget {
  /// Shown as the app bar title — customize per call site, e.g.
  /// "Scan Product Serial" vs "Scan to Find Product".
  final String title;

  const SerialScanScreen({super.key, this.title = 'Scan Serial Number'});

  @override
  State<SerialScanScreen> createState() => _SerialScanScreenState();
}

class _SerialScanScreenState extends State<SerialScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false; // guards against firing twice on the same frame

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue?.trim();
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Dimmed backdrop with a clear viewfinder cut-out.
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFF00D4AA), width: 2.5),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Text(
              'Point the camera at the barcode / QR code',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.85)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Setup (one-time) ────────────────────────────────────────────────────
// 1. pubspec.yaml:
//      dependencies:
//        mobile_scanner: ^5.2.3
//    then `flutter pub get`.
// 2. iOS — ios/Runner/Info.plist:
//      <key>NSCameraUsageDescription</key>
//      <string>Camera access is needed to scan product serial numbers.</string>
// 3. Android — no extra config needed, the plugin handles it.