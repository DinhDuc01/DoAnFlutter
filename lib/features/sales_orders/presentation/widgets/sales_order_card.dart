import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../models/sales_order.dart';

/// Sắc thái chip trạng thái theo id — dùng chung cho card và màn chi tiết.
AppTone salesOrderTone(int statusId) => switch (statusId) {
      SalesOrderStatusIds.cancelled => AppTone.danger,
      SalesOrderStatusIds.completed => AppTone.success,
      SalesOrderStatusIds.delivering => AppTone.info,
      SalesOrderStatusIds.awaitingMilling => AppTone.warning,
      SalesOrderStatusIds.newOrder ||
      SalesOrderStatusIds.pendingConfirm =>
        AppTone.neutral,
      _ => AppTone.brand,
    };

/// Thẻ hiển thị một đơn bán trong danh sách.
class SalesOrderCard extends StatelessWidget {
  const SalesOrderCard({required this.order, required this.onTap, super.key});

  final SalesOrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryFor(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.soCode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              AppStatusChip(
                label: order.statusLabel,
                tone: salesOrderTone(order.statusId),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            order.customerName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${salesChannelLabel(order.channel)} • ${order.warehouseName ?? 'Chưa chọn kho'}',
            style: TextStyle(fontSize: 12, color: secondary),
          ),
          Text(
            'Ngày đặt ${formatDate(order.orderDate)}'
            '${order.expectedDeliveryDate == null ? '' : ' • Giao dự kiến ${formatDate(order.expectedDeliveryDate)}'}',
            style: TextStyle(fontSize: 12, color: secondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              // Expanded thay cho Spacer: số tiền lớn vẫn hiện đủ, phần thừa
              // mới bị cắt thay vì đẩy tràn cả hàng.
              Expanded(
                child: Text(
                  formatMoney(order.totalAmount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (order.requiresMilling) ...[
                const SizedBox(width: 6),
                const AppStatusChip(
                  label: 'Cần xay',
                  tone: AppTone.warning,
                  icon: Icons.grain_outlined,
                  dense: true,
                ),
              ],
              const Icon(Icons.chevron_right),
            ],
          ),
          if (order.requiresMilling && order.remainingMillingRiceKg > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Còn thiếu ${formatKg(order.remainingMillingRiceKg)} gạo cần xay',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ],
          if (order.statusId == SalesOrderStatusIds.cancelled &&
              (order.cancelReason?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Text(
              'Lý do hủy: ${order.cancelReason!.trim()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
