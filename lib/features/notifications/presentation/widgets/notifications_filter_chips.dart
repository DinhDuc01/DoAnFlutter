import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/app_notification.dart';

/// Widget danh sách các Chip chọn chế độ lọc thông báo (Notifications Filter Chips) (Tất cả, Chưa đọc, Cảnh báo).
class NotificationsFilterChips extends StatelessWidget {
  /// Khởi tạo [NotificationsFilterChips] nhận bộ lọc đang chọn, số lượng chưa đọc và callback.
  const NotificationsFilterChips({
    required this.selectedFilter,
    required this.unreadCount,
    required this.onChanged,
    this.alertCount = 0,
    super.key,
  });

  /// Bộ lọc thông báo đang được chọn.
  final NotificationFilter selectedFilter;

  /// Số lượng thông báo chưa đọc hiển thị dạng Badge.
  final int unreadCount;
  final int alertCount;

  /// Callback kích hoạt khi thay đổi bộ lọc được chọn.
  final ValueChanged<NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterChipButton(
            label: 'Tất cả',
            isSelected: selectedFilter == NotificationFilter.all,
            onTap: () => onChanged(NotificationFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Chưa đọc',
            badge: unreadCount,
            isSelected: selectedFilter == NotificationFilter.unread,
            onTap: () => onChanged(NotificationFilter.unread),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Cảnh báo',
            badge: alertCount,
            isSelected: selectedFilter == NotificationFilter.alerts,
            onTap: () => onChanged(NotificationFilter.alerts),
          ),
        ],
      ),
    );
  }
}

/// Nút bấm bộ lọc dạng Chip đơn lẻ (_FilterChipButton) có hỗ trợ Badge hiển thị số lượng.
class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  /// Nhãn hiển thị trên nút.
  final String label;

  /// Cờ kiểm tra xem Chip này có đang được chọn hay không.
  final bool isSelected;

  /// Callback khi chạm vào Chip.
  final VoidCallback onTap;

  /// Số lượng hiển thị ở Badge (nếu có).
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color:
                      isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              // Hiển thị vòng tròn Badge màu đỏ nếu có số lượng thông báo chưa đọc
              if (badge != null && badge! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
