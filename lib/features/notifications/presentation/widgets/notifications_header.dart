import 'package:flutter/material.dart';

/// Widget Header cho màn hình thông báo (Notifications Header).
/// Hiển thị tiêu đề, số lượng thông báo chưa đọc và nút để đánh dấu "Đọc tất cả".
class NotificationsHeader extends StatelessWidget {
  /// Khởi tạo [NotificationsHeader] nhận số lượng chưa đọc và callback.
  const NotificationsHeader({
    required this.unreadCount,
    required this.onMarkAllAsRead,
    super.key,
  });

  /// Số lượng thông báo chưa đọc.
  final int unreadCount;

  /// Callback kích hoạt khi nhấn nút "Đọc tất cả".
  final VoidCallback onMarkAllAsRead;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thông báo',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$unreadCount thông báo chưa đọc',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Nút bấm "Đọc tất cả", bị vô hiệu hóa nếu không có thông báo chưa đọc
          Flexible(
            child: TextButton(
              onPressed: unreadCount == 0 ? null : onMarkAllAsRead,
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Đọc tất cả'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
