import 'package:flutter/material.dart';

enum AppNotificationType {
  alert,
  warning,
  info,
  success,
}

enum NotificationFilter {
  all,
  unread,
  alerts,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.isRead,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String message;
  final String timeAgo;
  final bool isRead;

  bool get isAlert {
    return type == AppNotificationType.alert || type == AppNotificationType.warning;
  }

  IconData get icon {
    return switch (type) {
      AppNotificationType.alert => Icons.warning_amber_rounded,
      AppNotificationType.warning => Icons.notifications_none,
      AppNotificationType.info => Icons.inventory_2_outlined,
      AppNotificationType.success => Icons.check_circle_outline,
    };
  }

  Color get color {
    return switch (type) {
      AppNotificationType.alert => const Color(0xFFFF3B30),
      AppNotificationType.warning => const Color(0xFFFFA000),
      AppNotificationType.info => const Color(0xFF3B82F6),
      AppNotificationType.success => const Color(0xFF16B957),
    };
  }
}
