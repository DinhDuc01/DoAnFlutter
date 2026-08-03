import 'package:flutter/material.dart';

import '../../models/app_notification.dart';

/// Thẻ hiển thị một thông báo riêng lẻ (Notifications Card).
/// Hỗ trợ hiển thị chấm chưa đọc, nội dung thông báo, khoảng thời gian gửi và nút tắt thông báo.
class NotificationsCard extends StatelessWidget {
  /// Khởi tạo [NotificationsCard] nhận thông tin thông báo và sự kiện khi đóng.
  const NotificationsCard({
    required this.notification,
    required this.onDismissed,
    super.key,
  });

  /// Đối tượng chứa thông tin của thông báo.
  final AppNotification notification;

  /// Callback kích hoạt khi nhấn nút đóng "X" thông báo.
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon đại diện bên trái kèm màu sắc đặc trưng
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: notification.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              notification.icon,
              color: notification.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Phần nội dung thông báo chính
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    // Chấm nhỏ báo hiệu thông báo chưa đọc
                    if (!notification.isRead)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: notification.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.timeAgo,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Nút bấm "X" để tắt / ẩn thông báo
          InkWell(
            onTap: onDismissed,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
