import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/operation_history.dart';

/// Thẻ hiển thị một bản ghi lịch sử hoạt động kho (Operation History Card).
/// Hiển thị loại hoạt động, icon đại diện, sản phẩm chịu tác động, SKU, mã phiếu, thời gian và số lượng thay đổi.
class OperationHistoryCard extends StatelessWidget {
  /// Khởi tạo [OperationHistoryCard] với thông tin lịch sử.
  const OperationHistoryCard({
    required this.history,
    super.key,
  });

  /// Thông tin lịch sử hoạt động được hiển thị.
  final OperationHistory history;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon tròn thể hiện loại hoạt động (nhập/xuất/kiểm)
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: history.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              history.icon,
              color: history.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Thông tin chi tiết của hoạt động
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      history.typeLabel,
                      style: TextStyle(
                        color: history.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTime(history.createdAt),
                      style: TextStyle(
                        color: AppColors.textSecondaryFor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  history.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${history.sku} • ${history.referenceCode}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Số lượng thay đổi (+ tăng hoặc - giảm)
          if (history.quantityChange != 0)
            Text(
              _formatQuantity(history.quantityChange),
              style: TextStyle(
                color: history.color,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  /// Định dạng hiển thị số lượng thay đổi (VD: +50 hoặc -30)
  String _formatQuantity(int value) {
    if (value > 0) return '+$value';
    return value.toString();
  }

  /// Định dạng ngày tháng giờ phút hiển thị dạng dd/MM HH:mm
  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}
