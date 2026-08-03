import 'dart:io';

import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/app_notification.dart';
import 'notifications_repository.dart';

/// Hiện thực gọi REST API cho thông báo của người dùng đang đăng nhập.
///
/// Bao gồm: lấy danh sách (phân trang), đếm số chưa đọc, đổi trạng thái
/// (đã đọc/chưa đọc/đọc tất cả), xoá và đăng ký/huỷ token FCM của thiết bị.
class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  String get _requireToken {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiException(message: 'Bạn cần đăng nhập để xem thông báo.');
    }
    return token;
  }

  /// Lấy một trang thông báo. [isRead] = null lấy tất cả, false chỉ chưa đọc,
  /// true chỉ đã đọc.
  Future<NotificationPage> fetch({
    int pageIndex = 1,
    int pageSize = 10,
    bool? isRead,
  }) async {
    final token = _requireToken;
    final body = <String, dynamic>{
      'pageIndex': pageIndex,
      'pageSize': pageSize,
      if (isRead != null) 'isRead': isRead,
    };

    final json = await _apiClient.post(
      '/api/v1/notification/me',
      token: token,
      body: body,
    );
    final resources = JsonReader.map(json, 'resources');
    if (resources == null) {
      return const NotificationPage(items: [], total: 0);
    }

    final data = JsonReader.list(resources, 'dataSource') ?? const [];
    final total = JsonReader.integer(resources, 'totalFiltered') ??
        JsonReader.integer(resources, 'total') ??
        data.length;

    final items = <AppNotification>[
      for (final item in data)
        if (item is Map<String, dynamic>) _fromJson(item),
    ];
    return NotificationPage(items: items, total: total);
  }

  @override
  Future<List<AppNotification>> getNotifications() async {
    final page = await fetch(pageIndex: 1, pageSize: 50);
    return page.items;
  }

  /// Đếm số thông báo chưa đọc (dùng cho badge chuông). Chỉ cần lấy tổng nên
  /// pageSize = 1 để nhẹ.
  Future<int> unreadCount() async {
    final page = await fetch(pageIndex: 1, pageSize: 1, isRead: false);
    return page.total;
  }

  /// Đánh dấu một thông báo là đã đọc.
  Future<void> markRead(int userNotificationId) async {
    await _apiClient.put(
      '/api/v1/notification/me/$userNotificationId/mark-read',
      token: _requireToken,
    );
  }

  /// Đánh dấu một thông báo là chưa đọc.
  Future<void> markUnread(int userNotificationId) async {
    await _apiClient.put(
      '/api/v1/notification/me/$userNotificationId/mark-unread',
      token: _requireToken,
    );
  }

  /// Đánh dấu tất cả thông báo của tôi là đã đọc.
  Future<void> markAllRead() async {
    await _apiClient.put(
      '/api/v1/notification/me/mark-all-read',
      token: _requireToken,
    );
  }

  /// Xoá (ẩn) một thông báo của tôi.
  Future<void> delete(int userNotificationId) async {
    await _apiClient.delete(
      '/api/v1/notification/me/$userNotificationId',
      token: _requireToken,
    );
  }

  /// Đăng ký / cập nhật token FCM của thiết bị hiện tại lên server.
  Future<void> registerDeviceToken(String deviceToken) async {
    if (deviceToken.isEmpty) return;
    await _apiClient.post(
      '/api/v1/user-device/add-device-token',
      token: _requireToken,
      body: {
        'deviceToken': deviceToken,
        'platform': _platformName,
        'deviceName': _deviceName,
        'osVersion': _osVersion,
      },
    );
  }

  /// Huỷ token FCM của thiết bị (gọi khi đăng xuất) để không nhận đẩy nữa.
  Future<void> deleteDeviceToken(String deviceToken) async {
    if (deviceToken.isEmpty) return;
    await _apiClient.post(
      '/api/v1/user-device/delete-device-token',
      token: _requireToken,
      body: {'deviceToken': deviceToken},
    );
  }

  String get _platformName {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return Platform.operatingSystem;
  }

  String get _deviceName => 'Tuấn Mây Mobile ($_platformName)';

  String get _osVersion => Platform.operatingSystemVersion;

  AppNotification _fromJson(Map<String, dynamic> json) {
    final category = (JsonReader.string(json, 'notificationCategoryName') ?? '')
        .toLowerCase();
    final title = JsonReader.string(json, 'title') ?? 'Thông báo';
    final combined = '$category ${title.toLowerCase()}';
    final type = combined.contains('cảnh báo') || combined.contains('khẩn')
        ? AppNotificationType.alert
        : combined.contains('thành công')
            ? AppNotificationType.success
            : combined.contains('nhắc')
                ? AppNotificationType.warning
                : AppNotificationType.info;
    final createdAt = DateTime.tryParse(
      JsonReader.string(json, 'createdDate') ?? '',
    );

    final direction = JsonReader.string(json, 'directionId');

    return AppNotification(
      id: '${JsonReader.integer(json, 'id') ?? 0}',
      type: type,
      title: title,
      message: JsonReader.string(json, 'content') ?? '',
      timeAgo: _formatTimeAgo(createdAt),
      isRead: JsonReader.boolean(json, 'isRead') ?? false,
      directionId: (direction != null && direction.trim().isNotEmpty)
          ? direction.trim()
          : null,
    );
  }

  String _formatTimeAgo(DateTime? value) {
    if (value == null) return 'Không rõ thời gian';
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.isNegative || difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inMinutes < 60) return '${difference.inMinutes} phút trước';
    if (difference.inHours < 24) return '${difference.inHours} giờ trước';
    return '${difference.inDays} ngày trước';
  }
}
