import '../models/app_notification.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> getNotifications();
}

class MockNotificationsRepository implements NotificationsRepository {
  @override
  Future<List<AppNotification>> getNotifications() async {
    // API_SWAP: Replace this mock response with GET /notifications.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return const [
      AppNotification(
        id: 'noti-001',
        type: AppNotificationType.alert,
        title: 'Tồn kho thấp khẩn cấp',
        message: 'Bóng đèn LED 9W (SKU-0001) còn 8 cái',
        timeAgo: '5 phút trước',
        isRead: false,
      ),
      AppNotification(
        id: 'noti-002',
        type: AppNotificationType.warning,
        title: 'Kho C gần đầy',
        message: 'Đã sử dụng 90% sức chứa',
        timeAgo: '2 giờ trước',
        isRead: false,
      ),
      AppNotification(
        id: 'noti-003',
        type: AppNotificationType.info,
        title: 'Phiếu nhập cần xác nhận',
        message: 'PN-2025-004 chờ duyệt từ Admin',
        timeAgo: '3 giờ trước',
        isRead: false,
      ),
      AppNotification(
        id: 'noti-004',
        type: AppNotificationType.success,
        title: 'Xuất kho thành công',
        message: 'PX-2025-003 hoàn tất — 30 sản phẩm',
        timeAgo: '5 giờ trước',
        isRead: true,
      ),
      AppNotification(
        id: 'noti-005',
        type: AppNotificationType.info,
        title: 'Lịch kiểm kho mới',
        message: 'Kho B — kiểm kho ngày 16/07/2025',
        timeAgo: '1 ngày trước',
        isRead: true,
      ),
    ];
  }
}
