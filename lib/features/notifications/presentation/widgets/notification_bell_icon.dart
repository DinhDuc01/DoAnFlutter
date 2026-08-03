import 'package:flutter/material.dart';

import '../../data/notification_center.dart';

/// Icon chuông thông báo kèm badge số lượng chưa đọc, cập nhật realtime theo
/// [NotificationCenter.instance.unread]. Số hiển thị tối đa 99, vượt thì "99+".
class NotificationBellIcon extends StatelessWidget {
  const NotificationBellIcon({
    required this.icon,
    this.color,
    super.key,
  });

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationCenter.instance.unread,
      builder: (context, count, _) {
        final iconWidget = Icon(icon, color: color);
        if (count <= 0) return iconWidget;
        return Badge(
          label: Text(NotificationCenter.badgeLabel(count)),
          backgroundColor: const Color(0xFFFF3B30),
          child: iconWidget,
        );
      },
    );
  }
}
