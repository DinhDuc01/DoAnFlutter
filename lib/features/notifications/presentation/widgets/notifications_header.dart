import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class NotificationsHeader extends StatelessWidget {
  const NotificationsHeader({
    required this.unreadCount,
    required this.onMarkAllAsRead,
    super.key,
  });

  final int unreadCount;
  final VoidCallback onMarkAllAsRead;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thông báo',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$unreadCount thông báo chưa đọc',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: unreadCount == 0 ? null : onMarkAllAsRead,
            child: const Text('Đọc tất cả'),
          ),
        ],
      ),
    );
  }
}
