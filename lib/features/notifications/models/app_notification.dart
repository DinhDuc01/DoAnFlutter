import 'package:flutter/material.dart';

/// Các phân loại thông báo trong hệ thống.
enum AppNotificationType {
  /// Cảnh báo khẩn cấp (Alert)
  alert,

  /// Cảnh báo nhắc nhở (Warning)
  warning,

  /// Thông tin (Info)
  info,

  /// Thành công (Success)
  success,
}

/// Các chế độ lọc thông báo trên giao diện.
enum NotificationFilter {
  /// Hiển thị tất cả thông báo
  all,

  /// Chỉ hiển thị thông báo chưa đọc
  unread,

  /// Chỉ hiển thị các cảnh báo quan trọng
  alerts,
}

/// Đại diện cho một thông báo trong ứng dụng (App Notification).
class AppNotification {
  /// Khởi tạo [AppNotification] với các thông số bắt buộc.
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.isRead,
    this.directionId,
  });

  /// Mã định danh của thông báo (userNotificationId, dùng cho mark-read/unread/xoá).
  final String id;

  /// Đường dẫn nội bộ (kiểu web) do backend gửi kèm để điều hướng khi bấm vào thông báo.
  /// Có thể null nếu thông báo không gắn với màn hình cụ thể.
  final String? directionId;

  /// Id dạng số của thông báo để gọi API (mark-read/unread/xoá).
  int get numericId => int.tryParse(id) ?? 0;

  /// Phân loại loại thông báo.
  final AppNotificationType type;

  /// Tiêu đề thông báo.
  final String title;

  /// Nội dung thông báo.
  final String message;

  /// Khoảng thời gian đã trôi qua kể từ khi tạo thông báo (VD: 5 phút trước).
  final String timeAgo;

  /// Trạng thái đã đọc hay chưa.
  final bool isRead;

  /// Kiểm tra xem thông báo này có phải dạng cảnh báo cần chú ý hay không.
  bool get isAlert {
    return type == AppNotificationType.alert ||
        type == AppNotificationType.warning;
  }

  /// Tạo bản sao với một vài trường được thay đổi (VD: đánh dấu đã đọc).
  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      timeAgo: timeAgo,
      isRead: isRead ?? this.isRead,
      directionId: directionId,
    );
  }

  /// Trả về biểu tượng Icon tương ứng cho từng loại thông báo.
  IconData get icon {
    return switch (type) {
      AppNotificationType.alert => Icons.warning_amber_rounded,
      AppNotificationType.warning => Icons.notifications_none,
      AppNotificationType.info => Icons.inventory_2_outlined,
      AppNotificationType.success => Icons.check_circle_outline,
    };
  }

  /// Trả về màu sắc đặc trưng đại diện cho từng loại thông báo.
  Color get color {
    return switch (type) {
      AppNotificationType.alert => const Color(0xFFFF3B30),
      AppNotificationType.warning => const Color(0xFFFFA000),
      AppNotificationType.info => const Color(0xFF3B82F6),
      AppNotificationType.success => const Color(0xFF16B957),
    };
  }
}
