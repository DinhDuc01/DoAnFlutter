import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ScanCameraPreview extends StatelessWidget {
  const ScanCameraPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F1E3A),
            Color(0xFF0B172A),
            Color(0xFF07150F),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 190,
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _ScanCorners(),
                  _QrGlyph(),
                ],
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Căn mã QR vào khung để quét',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
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

class _QrGlyph extends StatelessWidget {
  const _QrGlyph();

  @override
  Widget build(BuildContext context) {
    const cells = [
      true,
      true,
      true,
      false,
      true,
      false,
      true,
      false,
      false,
    ];

    return SizedBox(
      width: 76,
      height: 76,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cells.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
        ),
        itemBuilder: (context, index) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: cells[index]
                  ? AppColors.primary.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        },
      ),
    );
  }
}
