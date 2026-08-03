import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/api_notifications_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiNotificationsRepository();
    _notificationsFuture = _repository.getNotifications();
  }

  void _reload() {
    setState(() {
      _notificationsFuture = _repository.getNotifications();
    });
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
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  await _notificationsFuture;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      notifications.length > 5 ? 5 : notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => NotificationsCard(
                    notification: notifications[index],
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
