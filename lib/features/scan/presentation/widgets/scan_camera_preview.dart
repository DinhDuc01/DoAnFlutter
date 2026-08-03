import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/scan_result_info.dart';

/// Widget xem trước Camera để quét mã QR/Barcode (Scan Camera Preview).
/// Tích hợp thư viện mobile_scanner, phủ lớp màu tối, vẽ khung góc xanh lá hướng dẫn quét và hiển thị nội dung quét được.
class ScanCameraPreview extends StatelessWidget {
  /// Khởi tạo [ScanCameraPreview] nhận bộ điều khiển, callback khi nhận diện và kết quả hiện tại.
  const ScanCameraPreview({
    required this.controller,
    required this.onDetect,
    this.result,
    super.key,
  });

  /// Bộ điều khiển camera.
  final MobileScannerController controller;

  /// Callback kích hoạt khi camera nhận diện được một mã vạch/QR.
  final void Function(BarcodeCapture capture) onDetect;

  /// Thông tin kết quả quét hiện tại (nếu có).
  final ScanResultInfo? result;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera thu hình từ mobile_scanner
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
        // Lớp phủ tối mờ gradient để làm nổi bật khung quét
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
        // Khung quét nằm giữa màn hình kèm văn bản hướng dẫn
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
                    _ScanCorners(), // Vẽ 4 góc khung quét
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                result == null
                    ? 'Căn mã QR hoặc barcode vào khung để quét'
                    : result!.title,
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

/// Widget gom nhóm 4 góc viền của khung quét mã (_ScanCorners).
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

/// Một góc viền riêng lẻ của khung quét (_Corner) được xoay theo góc tương ứng.
class _Corner extends StatelessWidget {
  const _Corner({
    required this.alignment,
    this.rotate = 0,
  });

  /// Vị trí góc (Ví dụ: topLeft, topRight...).
  final Alignment alignment;

  /// Giá trị xoay (0 = topLeft, 1 = topRight, 2 = bottomRight, 3 = bottomLeft).
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

/// Bộ vẽ CustomPainter vẽ hình chữ L bo góc cho khung quét mã.
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
