import '../models/app_notification.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> getNotifications();
}
