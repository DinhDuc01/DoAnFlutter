import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget Header cho màn hình Lịch sử thao tác (Operation History Header).
/// Hiển thị nút quay lại, tiêu đề trang và tổng số giao dịch/thao tác hiện có.
class OperationHistoryHeader extends StatelessWidget {
  /// Khởi tạo [OperationHistoryHeader] nhận tổng số lượng giao dịch.
  const OperationHistoryHeader({
    required this.count,
    super.key,
  });

  /// Tổng số lượng giao dịch lịch sử hiển thị.
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Lịch sử thao tác',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '$count giao dịch',
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
