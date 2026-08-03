import 'package:flutter/material.dart';

/// Widget Header cho màn hình quét mã QR/Barcode (Scan Header).
/// Có nền đen mờ phù hợp với camera preview, chứa nút quay lại trang cũ và nút bật/tắt đèn Flash.
class ScanHeader extends StatelessWidget {
  /// Khởi tạo [ScanHeader] nhận callback bật/tắt đèn Flash.
  const ScanHeader({
    required this.onToggleTorch,
    super.key,
  });

  /// Callback kích hoạt khi nhấn nút bật/tắt đèn Flash.
  final VoidCallback onToggleTorch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: Colors.black,
      child: Row(
        children: [
          // Nút bấm quay lại trang trước
          IconButton.filled(
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back),
          ),
          const Expanded(
            child: Text(
              'Quét mã QR',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // Nút bấm bật/tắt đèn Flash trợ sáng
          IconButton.filled(
            onPressed: onToggleTorch,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
    );
  }
}
