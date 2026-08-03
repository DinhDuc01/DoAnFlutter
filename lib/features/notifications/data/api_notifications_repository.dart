import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/app_notification.dart';
import 'notifications_repository.dart';

class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<List<AppNotification>> getNotifications() async {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiException(message: 'Bạn cần đăng nhập để xem thông báo.');
    }

    final json = await _apiClient.post(
      '/api/v1/notification/me',
      token: token,
      body: const {'pageIndex': 1, 'pageSize': 50},
    );
    final resources = JsonReader.map(json, 'resources');
    final data = resources == null
        ? const <dynamic>[]
        : JsonReader.list(resources, 'dataSource') ?? const [];

    return [
      for (final item in data)
        if (item is Map<String, dynamic>) _fromJson(item),
    ];
  }

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

    return AppNotification(
      id: '${JsonReader.integer(json, 'id') ?? 0}',
      type: type,
      title: title,
      message: JsonReader.string(json, 'content') ?? '',
      timeAgo: _formatTimeAgo(createdAt),
      isRead: JsonReader.boolean(json, 'isRead') ?? false,
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
