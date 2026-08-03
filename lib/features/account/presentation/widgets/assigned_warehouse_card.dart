import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/account_profile.dart';

/// Thẻ hiển thị thông tin Kho hàng được chỉ định (Assigned Warehouse Card) trong trang cá nhân.
class AssignedWarehouseCard extends StatelessWidget {
  const AssignedWarehouseCard({
    required this.profile,
    super.key,
  });

  /// Thông tin hồ sơ chứa tên kho đang phụ trách.
  final AccountProfile profile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Icon hình ngôi nhà/kho hàng được bo viền tròn màu xanh nhạt
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.warehouse_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Cột văn bản nhãn và tên Kho hàng phụ trách thực tế
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kho đang phụ trách',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.assignedWarehouse,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          // Icon mũi tên chỉ sang phải biểu thị có thể click để xem chi tiết
          Icon(
            Icons.chevron_right,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }
}
