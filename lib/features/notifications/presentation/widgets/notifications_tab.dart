import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/api_notifications_repository.dart';
import '../../data/notification_center.dart';
import '../../data/notifications_repository.dart';
import '../../models/app_notification.dart';
import 'notifications_card.dart';
import 'notifications_filter_chips.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({this.repository, super.key});

  final NotificationsRepository? repository;

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  late final NotificationsRepository _repository;
  late Future<List<AppNotification>> _notificationsFuture;
  StreamSubscription<void>? _refreshSub;
  NotificationFilter _filter = NotificationFilter.all;

  ApiNotificationsRepository? get _api =>
      _repository is ApiNotificationsRepository ? _repository : null;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiNotificationsRepository();
    _notificationsFuture = _repository.getNotifications();
    // Táº£i láº¡i preview khi cÃ³ thÃ´ng bÃ¡o Ä‘áº©y realtime.
    _refreshSub = NotificationCenter.instance.onRefresh.listen((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _notificationsFuture = _repository.getNotifications();
    });
  }

  Future<void> _refreshNotifications() async {
    _reload();
    await _notificationsFuture;
  }

  Future<void> _onTap(AppNotification notification) async {
    final api = _api;
    if (!notification.isRead && api != null) {
      try {
        await api.markRead(notification.numericId);
        await NotificationCenter.instance.refreshUnread();
      } catch (_) {
        // Bá» qua.
      }
    }
    if (!mounted) return;

    /* Preview taps open the full notification list. */
    await Navigator.of(context).pushNamed(AppRoutes.notifications);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Cảnh báo kho',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                tooltip: 'Tải lại',
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AppNotification>>(
            future: _notificationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const ListSkeleton();
              }
              if (snapshot.hasError) {
                return HErrorState(
                  message: 'Không tải được thông báo: ${snapshot.error}',
                  onRetry: _reload,
                );
              }
              final notifications = snapshot.data ?? const [];
              if (notifications.isEmpty) {
                return const HEmptyState(
                  title: 'Không có thông báo mới',
                  description:
                      'Server chưa gửi thông báo nào cho tài khoản này.',
                  icon: Icons.notifications_off_outlined,
                );
              }
              // The backend already returns the current notification page;
              // do not truncate it in the home preview.
              final unreadCount =
                  notifications.where((item) => !item.isRead).length;
              final alertCount =
                  notifications.where((item) => item.isAlert).length;
              final visible = switch (_filter) {
                NotificationFilter.all => notifications,
                NotificationFilter.unread =>
                  notifications.where((item) => !item.isRead).toList(),
                NotificationFilter.alerts =>
                  notifications.where((item) => item.isAlert).toList(),
              };
              return RefreshIndicator(
                onRefresh: _refreshNotifications,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: visible.isEmpty ? 2 : visible.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return NotificationsFilterChips(
                        selectedFilter: _filter,
                        unreadCount: unreadCount,
                        alertCount: alertCount,
                        onChanged: (filter) => setState(() => _filter = filter),
                      );
                    }
                    if (visible.isEmpty) {
                      return const HEmptyState(
                        title: 'Không có thông báo phù hợp',
                        description: 'Hãy thử chọn bộ lọc khác.',
                        icon: Icons.notifications_none,
                      );
                    }
                    final notification = visible[index - 1];
                    return NotificationsCard(
                      notification: notification,
                      onTap: () => _onTap(notification),
                      onDismissed: () => Navigator.of(context).pushNamed(
                        AppRoutes.notifications,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
