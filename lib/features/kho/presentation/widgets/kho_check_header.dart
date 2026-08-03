import 'package:flutter/material.dart';

/// Widget Header cho màn hình kiểm kê kho (Inventory Check Header).
/// Header của phiếu kiểm kê tồn kho.
class KhoCheckHeader extends StatelessWidget {
  const KhoCheckHeader({
    this.status = 'Bản nháp',
    this.statusBgColor,
    this.statusTextColor,
    super.key,
  });

  /// Nhãn trạng thái phiếu.
  final String status;

  /// Màu nền của nhãn trạng thái (nếu null, mặc định màu tím nhạt).
  final Color? statusBgColor;

  /// Màu chữ của nhãn trạng thái (nếu null, mặc định màu tím đậm).
  final Color? statusTextColor;

  static const _accent = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          // Nút bấm quay lại trang trước
          IconButton.filledTonal(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Phiếu kiểm kê',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          // Trạng thái phiếu kiểm kê.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusBgColor ?? _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusTextColor ?? _accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
