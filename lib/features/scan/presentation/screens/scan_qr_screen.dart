import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/scan_result_info.dart';
import '../widgets/scan_action_panel.dart';
import '../widgets/scan_bottom_bar.dart';
import '../widgets/scan_camera_preview.dart';
import '../widgets/scan_header.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  ScanResultInfo? _lastResult;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final result = ScanResultInfo.fromBarcode(barcode);
    if (result.rawValue.isEmpty || result.rawValue == _lastResult?.rawValue) return;

    setState(() => _lastResult = result);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${result.title}: ${result.productCode ?? result.rawValue}'),
      ),
    );
  }

  Future<void> _toggleTorch() => _controller.toggleTorch();

  Future<void> _switchCamera() => _controller.switchCamera();

  void _resumeScanning() {
    setState(() => _lastResult = null);
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            ScanHeader(onToggleTorch: _toggleTorch),
            Expanded(
              child: ScanCameraPreview(
                controller: _controller,
                onDetect: _handleDetect,
                result: _lastResult,
              ),
            ),
            ScanActionPanel(
              result: _lastResult,
              onScanAgain: _resumeScanning,
              onSwitchCamera: _switchCamera,
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ScanBottomBar(),
    );
  }
}
