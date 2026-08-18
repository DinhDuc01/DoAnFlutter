import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_notifications_repository.dart';

/// Trung tâm điều phối trạng thái thông báo realtime cho toàn app.
///
/// - [unread]: số thông báo chưa đọc, hiển thị trên badge chuông (bottom nav).
///   Cập nhật tức thời khi có thông báo đẩy FCM hoặc sau khi đổi trạng thái.
/// - [onRefresh]: phát tín hiệu để các màn đang mở tự tải lại danh sách.
class NotificationCenter {
  NotificationCenter._();

  /// Thể hiện singleton dùng chung.
  static final NotificationCenter instance = NotificationCenter._();

  final ApiNotificationsRepository _repository = ApiNotificationsRepository();

  /// Số thông báo chưa đọc hiện tại (0 nếu chưa đăng nhập).
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  final StreamController<void> _refreshController =
      StreamController<void>.broadcast();

  /// Tín hiệu yêu cầu các màn đang mở tải lại danh sách thông báo.
  Stream<void> get onRefresh => _refreshController.stream;

  /// Nhãn hiển thị trên badge: tối đa 99, vượt 99 -> "99+".
  static String badgeLabel(int count) => count > 99 ? '99+' : '$count';

  /// Tải lại số chưa đọc từ server (bỏ qua lỗi để không làm sập UI).
  Future<void> refreshUnread() async {
    try {
      unread.value = await _repository.unreadCount();
    } catch (_) {
      // Giữ nguyên giá trị cũ nếu gọi API thất bại.
    }
  }

  /// Yêu cầu các màn đang mở tải lại danh sách.
  void requestListRefresh() {
    if (!_refreshController.isClosed) _refreshController.add(null);
  }

  /// Vừa cập nhật badge chưa đọc vừa yêu cầu tải lại danh sách. Gọi khi nhận
  /// thông báo đẩy realtime.
  Future<void> reloadAll() async {
    await refreshUnread();
    requestListRefresh();
  }

  /// Đặt lại số chưa đọc (gọi khi đăng xuất).
  void reset() {
    unread.value = 0;
  }

  /// Điều chỉnh badge cục bộ để phản hồi ngay (VD: sau khi đọc 1 thông báo)
  /// mà không cần chờ round-trip tới server.
  void decrementUnread([int by = 1]) {
    final next = unread.value - by;
    unread.value = next < 0 ? 0 : next;
  }
}
