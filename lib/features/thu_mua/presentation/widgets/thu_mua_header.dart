import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget Header cho màn hình nhập kho (Inbound Header).
/// Hiển thị nút Back, tiêu đề trang và nhãn trạng thái hiện thời của phiếu nhập kho (ví dụ: "Nhập kho").
class ThuMuaHeader extends StatelessWidget {
  const ThuMuaHeader({
    required this.status,
    super.key,
  });

  /// Trạng thái của phiếu nhập kho (ví dụ: "Nhập kho") để hiển thị trên chip trạng thái.
  final String status;

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
              'Phiếu nhập kho',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          // Chip trạng thái của phiếu nhập kho
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: const TextStyle(
                color: AppColors.primaryDark,
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
