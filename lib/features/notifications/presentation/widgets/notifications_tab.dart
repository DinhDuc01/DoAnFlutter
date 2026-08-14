import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/realtime/realtime_reload_mixin.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/api_notifications_repository.dart';
import '../../data/notification_center.dart';
import '../../data/notification_navigator.dart';
import '../../data/notifications_repository.dart';
import '../../models/app_notification.dart';
import 'notifications_card.dart';
import 'notifications_filter_chips.dart';

/// Tab "Thông báo" — nay là màn danh sách đầy đủ duy nhất.
///
/// Trước đây còn một `NotificationsScreen` riêng (kèm bottom bar giả) làm bản
/// sao của tab này: bấm vào một thông báo trong tab lại đẩy sang màn kia. Màn
/// đó đã bị xoá, nên tab phải nhận luôn các hành động vốn chỉ có ở đó — quan
/// trọng nhất là nút "Đọc tất cả".
class NotificationsTab extends StatefulWidget {
  const NotificationsTab({this.repository, super.key});

  final NotificationsRepository? repository;

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab>
    with RealtimeReloadMixin {
  /// FCM chỉ đẩy khi có thông báo MỚI. Đọc/đọc-tất-cả ở web hay máy khác không
  /// sinh push nên vẫn cần SignalR để danh sách và badge khớp nhau.
  @override
  Set<String> get realtimeEntities => const {
        'Notification',
        'UserNotification',
      };

  @override
  void onRealtimeChanged() => _load(showLoading: false);

  late final NotificationsRepository _repository;

  StreamSubscription<void>? _refreshSub;
  NotificationFilter _filter = NotificationFilter.all;

  List<AppNotification> _notifications = const [];
  Object? _error;
  bool _loading = true;
  bool _markingAll = false;

  ApiNotificationsRepository? get _api =>
      _repository is ApiNotificationsRepository
          ? _repository as ApiNotificationsRepository
          : null;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiNotificationsRepository();
    // _loading đã mặc định true nên không cần (và không được) setState ở đây.
    _load(showLoading: false);
    // Tải lại khi có thông báo đẩy realtime.
    _refreshSub = NotificationCenter.instance.onRefresh.listen((_) {
      if (mounted) _load(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await _repository.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  int get _unreadCount =>
      _notifications.where((item) => !item.isRead).length;

  List<AppNotification> get _visible => switch (_filter) {
        NotificationFilter.all => _notifications,
        NotificationFilter.unread => [
            for (final item in _notifications)
              if (!item.isRead) item,
          ],
        NotificationFilter.alerts => [
            for (final item in _notifications)
              if (item.isAlert) item,
          ],
      };

  void _replace(AppNotification updated) {
    setState(() {
      _notifications = [
        for (final item in _notifications)
          if (item.id == updated.id) updated else item,
      ];
    });
  }

  /// Bấm vào thông báo: đánh dấu đã đọc, rồi đi tới màn liên quan nếu có.
  Future<void> _onTap(AppNotification notification) async {
    if (!notification.isRead) {
      _replace(notification.copyWith(isRead: true));
      try {
        await _api?.markRead(notification.numericId);
        await NotificationCenter.instance.refreshUnread();
      } catch (_) {
        // UI đã cập nhật optimistic, lỗi mạng không cần chặn người dùng.
      }
    }
    if (!mounted) return;

    // Chỉ điều hướng khi backend chỉ đúng một màn có trên mobile.
    final route = NotificationNavigator.routeFor(notification.directionId);
    if (route != null) await Navigator.of(context).pushNamed(route);
  }

  Future<void> _dismiss(AppNotification notification) async {
    setState(() {
      _notifications = [
        for (final item in _notifications)
          if (item.id != notification.id) item,
      ];
    });
    try {
      await _api?.delete(notification.numericId);
      await NotificationCenter.instance.refreshUnread();
    } catch (_) {
      // Bỏ qua lỗi xoá phía server.
    }
  }

  /// Đọc tất cả — gọi API `PUT /notification/me/mark-all-read`.
  Future<void> _markAllAsRead() async {
    if (_markingAll || _unreadCount == 0) return;
    final snapshot = _notifications;
    setState(() {
      _markingAll = true;
      _notifications = [
        for (final item in _notifications) item.copyWith(isRead: true),
      ];
    });
    try {
      await _api?.markAllRead();
      await NotificationCenter.instance.refreshUnread();
    } catch (error) {
      // Thất bại thì trả lại đúng trạng thái cũ, không để UI nói dối.
      if (mounted) {
        setState(() => _notifications = snapshot);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không đánh dấu được đã đọc: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _unreadCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppGradientHeader(
          title: 'Thông báo',
          subtitle: unread == 0
              ? 'Đã đọc hết thông báo'
              : '$unread thông báo chưa đọc',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MarkAllButton(
                enabled: unread > 0 && !_markingAll,
                busy: _markingAll,
                onPressed: _markAllAsRead,
              ),
              IconButton(
                onPressed: () => _load(),
                color: Colors.white,
                icon: const Icon(Icons.refresh),
                tooltip: 'Tải lại',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _body(unread)),
      ],
    );
  }

  Widget _body(int unread) {
    if (_loading && _notifications.isEmpty) return const ListSkeleton();
    if (_error != null && _notifications.isEmpty) {
      return HErrorState(
        message: 'Không tải được thông báo: $_error',
        onRetry: _load,
      );
    }
    if (_notifications.isEmpty) {
      return const HEmptyState(
        title: 'Không có thông báo mới',
        description: 'Server chưa gửi thông báo nào cho tài khoản này.',
        icon: Icons.notifications_off_outlined,
      );
    }

    final visible = _visible;
    final alertCount = _notifications.where((item) => item.isAlert).length;

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: visible.isEmpty ? 2 : visible.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return NotificationsFilterChips(
              selectedFilter: _filter,
              unreadCount: unread,
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
            onDismissed: () => _dismiss(notification),
          );
        },
      ),
    );
  }
}

/// Nút "Đọc tất cả" đặt trên header xanh.
class _MarkAllButton extends StatelessWidget {
  const _MarkAllButton({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled ? Colors.white : Colors.white54;
    return Material(
      color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.08),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox.square(
                  dimension: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              else
                Icon(Icons.done_all_rounded, size: 15, color: foreground),
              const SizedBox(width: 5),
              Text(
                'Đọc tất cả',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
