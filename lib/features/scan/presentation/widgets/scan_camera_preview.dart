import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/scan_result_info.dart';

class ScanCameraPreview extends StatelessWidget {
  const ScanCameraPreview({
    required this.controller,
    required this.onDetect,
    this.result,
    super.key,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture capture) onDetect;
  final ScanResultInfo? result;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: onDetect,
          errorBuilder: (context, error) {
            return const ColoredBox(
              color: Color(0xFF0B172A),
              child: Center(
                child: Text(
                  'Không mở được camera',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.20),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.35),
              ],
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 190,
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _ScanCorners(),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                result == null ? 'Căn mã QR hoặc barcode vào khung để quét' : result!.title,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (result?.productCode != null) ...[
                const SizedBox(height: 6),
                Text(
                  result!.productCode!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanCorners extends StatelessWidget {
  const _ScanCorners();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        _Corner(alignment: Alignment.topLeft),
        _Corner(alignment: Alignment.topRight, rotate: 1),
        _Corner(alignment: Alignment.bottomRight, rotate: 2),
        _Corner(alignment: Alignment.bottomLeft, rotate: 3),
      ],
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({
    required this.alignment,
    this.rotate = 0,
  });

  final Alignment alignment;
  final int rotate;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: rotate * 1.5708,
        child: SizedBox(
          width: 34,
          height: 34,
          child: CustomPaint(painter: _CornerPainter()),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 8)
      ..quadraticBezierTo(0, 0, 8, 0)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
