import 'dart:async';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mihox/common/common.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanComplete = false;

  void _handleBarcode(BarcodeCapture capture) {
    if (_isScanComplete) return;

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isScanComplete = true);
    Navigator.pop<String>(context, rawValue);
  }

  Future<void> _scanFromImage() async {
    final imagePath = system.isDesktop
        ? (await FilePicker.platform.pickFiles(type: FileType.image))
            ?.files
            .single
            .path
        : (await ImagePicker().pickImage(source: ImageSource.gallery))?.path;

    if (imagePath == null) return;

    final result = await _scannerController.analyzeImage(imagePath);
    if (result != null && result.barcodes.isNotEmpty) {
      _handleBarcode(result);
    } else if (mounted) {
      await context.showNotifier(appLocalizations.qrNotFound);
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double sideLength =
        min(400, MediaQuery.of(context).size.width * 0.67);
    final scanWindow = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2),
      width: sideLength,
      height: sideLength,
    );

    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            scanWindow: scanWindow,
            onDetect: _handleBarcode,
          ),
          CustomPaint(
            painter: ScannerOverlay(scanWindow: scanWindow),
          ),
          AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                color: Colors.white,
                icon: ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _scannerController,
                  builder: (context, state, child) =>
                      switch (state.torchState) {
                    TorchState.on =>
                      const Icon(Icons.flash_on, color: Colors.yellow),
                    _ => const Icon(Icons.flash_off, color: Colors.grey),
                  },
                ),
                onPressed: _scannerController.toggleTorch,
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: IconButton(
                color: Colors.white,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                      Colors.black.withValues(alpha: 0.5)),
                ),
                padding: const EdgeInsets.all(16),
                iconSize: 32.0,
                onPressed: _scanFromImage,
                icon: const Icon(Icons.photo_library_outlined),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  const ScannerOverlay({
    required this.scanWindow,
    this.borderRadius = 12.0,
  });

  final Rect scanWindow;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final cutout = RRect.fromRectAndRadius(
      scanWindow,
      Radius.circular(borderRadius),
    );

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.largest),
      Path()..addRRect(cutout),
    );

    canvas
      ..drawPath(
        backgroundWithCutout,
        Paint()..color = Colors.black.withValues(alpha: 0.5),
      )
      ..drawRRect(
        cutout,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0,
      );
  }

  @override
  bool shouldRepaint(ScannerOverlay oldDelegate) =>
      scanWindow != oldDelegate.scanWindow ||
      borderRadius != oldDelegate.borderRadius;
}
