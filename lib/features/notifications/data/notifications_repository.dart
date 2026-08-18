import '../models/app_notification.dart';

/// Một trang thông báo trả về từ API (kèm tổng số bản ghi để phân trang).
class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.total,
  });

  /// Danh sách thông báo của trang hiện tại.
  final List<AppNotification> items;

  /// Tổng số bản ghi (đã lọc) để tính tổng số trang.
  final int total;
}

/// Kho dữ liệu thông báo. Giữ [getNotifications] để tương thích các màn cũ/test;
/// các thao tác nâng cao (phân trang, đổi trạng thái, đăng ký token FCM) nằm ở
/// [ApiNotificationsRepository].
abstract class NotificationsRepository {
  Future<List<AppNotification>> getNotifications();
}
