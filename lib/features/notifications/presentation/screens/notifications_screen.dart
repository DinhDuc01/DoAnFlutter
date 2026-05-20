import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/notifications_repository.dart';
import '../../models/app_notification.dart';
import '../widgets/notifications_bottom_bar.dart';
import '../widgets/notifications_card.dart';
import '../widgets/notifications_filter_chips.dart';
import '../widgets/notifications_header.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationsRepository _repository = MockNotificationsRepository();

  late final Future<List<AppNotification>> _notificationsFuture;
  List<AppNotification> _notifications = const [];
  NotificationFilter _filter = NotificationFilter.all;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // API_SWAP: This is where the screen requests notifications data.
    _notificationsFuture = _repository.getNotifications();
  }

  void _initializeNotifications(List<AppNotification> notifications) {
    if (_initialized) return;
    _notifications = notifications;
    _initialized = true;
  }

  void _removeNotification(String id) {
    // API_SWAP: Call DELETE /notifications/{id} or PATCH dismiss=true.
    setState(() {
      _notifications = [
        for (final notification in _notifications)
          if (notification.id != id) notification,
      ];
    });
  }

  void _markAllAsRead() {
    // API_SWAP: Call PATCH /notifications/read-all.
    setState(() {
      _notifications = [
        for (final notification in _notifications)
          AppNotification(
            id: notification.id,
            type: notification.type,
            title: notification.title,
            message: notification.message,
            timeAgo: notification.timeAgo,
            isRead: true,
          ),
      ];
    });
  }

  List<AppNotification> get _filteredNotifications {
    return switch (_filter) {
      NotificationFilter.all => _notifications,
      NotificationFilter.unread => [
          for (final notification in _notifications)
            if (!notification.isRead) notification,
        ],
      NotificationFilter.alerts => [
          for (final notification in _notifications)
            if (notification.isAlert) notification,
        ],
    };
  }

  int get _unreadCount {
    return _notifications.where((notification) => !notification.isRead).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundStart,
      body: SafeArea(
        child: FutureBuilder<List<AppNotification>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Không tải được thông báo'));
            }

            _initializeNotifications(snapshot.data!);
            final filteredNotifications = _filteredNotifications;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NotificationsHeader(
                  unreadCount: _unreadCount,
                  onMarkAllAsRead: _markAllAsRead,
                ),
                NotificationsFilterChips(
                  selectedFilter: _filter,
                  unreadCount: _unreadCount,
                  onChanged: (filter) {
                    setState(() => _filter = filter);
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filteredNotifications.isEmpty
                      ? const Center(child: Text('Không có thông báo phù hợp'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: filteredNotifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final notification = filteredNotifications[index];
                            return NotificationsCard(
                              notification: notification,
                              onDismissed: () => _removeNotification(notification.id),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const NotificationsBottomBar(),
    );
  }
}
