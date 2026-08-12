import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget Header cho màn hình xuất kho (Outbound Header).
/// Hiển thị nút Quay lại, tiêu đề trang và nhãn trạng thái tùy biến màu sắc (ví dụ: "Xuất kho", "Sai sản phẩm", "Thiếu hàng").
class GiaoHangHeader extends StatelessWidget {
  const GiaoHangHeader({
    required this.status,
    this.statusBgColor,
    this.statusTextColor,
    super.key,
  });

  /// Văn bản trạng thái hiển thị trên chip (ví dụ: "Xuất kho").
  final String status;

  /// Màu nền của chip trạng thái (nếu null, sử dụng màu xanh dương nhạt mặc định).
  final Color? statusBgColor;

  /// Màu chữ của chip trạng thái (nếu null, sử dụng màu xanh dương mặc định).
  final Color? statusTextColor;

  static const _accent = AppColors.info;

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
              'Bán hàng (xuất kho)',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          // Chip hiển thị trạng thái động
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
