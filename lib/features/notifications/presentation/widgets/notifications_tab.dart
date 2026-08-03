import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/api_notifications_repository.dart';
import '../../data/notification_center.dart';
import '../../data/notification_navigator.dart';
import '../../data/notifications_repository.dart';
import '../../models/app_notification.dart';
import 'notifications_card.dart';

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

  ApiNotificationsRepository? get _api =>
      _repository is ApiNotificationsRepository
          ? _repository as ApiNotificationsRepository
          : null;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiNotificationsRepository();
    _notificationsFuture = _repository.getNotifications();
    // Tải lại preview khi có thông báo đẩy realtime.
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

  Future<void> _onTap(AppNotification notification) async {
    final api = _api;
    if (!notification.isRead && api != null) {
      try {
        await api.markRead(notification.numericId);
        await NotificationCenter.instance.refreshUnread();
      } catch (_) {
        // Bỏ qua.
      }
    }
    if (!mounted) return;

    final route = NotificationNavigator.routeFor(notification.directionId);
    if (route != null) {
      await Navigator.of(context).pushNamed(route);
    } else {
      // Không có màn liên quan: mở danh sách thông báo để xem chi tiết.
      await Navigator.of(context).pushNamed(AppRoutes.notifications);
    }
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
                  'Thông báo của tôi',
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
              final visible = notifications.length > 5
                  ? notifications.sublist(0, 5)
                  : notifications;
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  await _notificationsFuture;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => NotificationsCard(
                    notification: visible[index],
                    onTap: () => _onTap(visible[index]),
                    onDismissed: () => Navigator.of(context).pushNamed(
                      AppRoutes.notifications,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
