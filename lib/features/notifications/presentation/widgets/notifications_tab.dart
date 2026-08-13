import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../data/api_notifications_repository.dart';
import '../../data/notification_center.dart';
import '../../data/notifications_repository.dart';
import '../../models/app_notification.dart';
import 'notifications_card.dart';
import 'notifications_filter_chips.dart';
import 'notifications_pager.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({this.repository, super.key});

  final NotificationsRepository? repository;

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  static const int _pageSize = 10;

  late final NotificationsRepository _repository;
  late Future<NotificationPage> _notificationsFuture;
  StreamSubscription<void>? _refreshSub;
  NotificationFilter _filter = NotificationFilter.all;
  bool _openingNotification = false;
  int _page = 1;
  int _total = 0;

  ApiNotificationsRepository? get _api =>
      _repository is ApiNotificationsRepository ? _repository : null;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiNotificationsRepository();
    _notificationsFuture = _loadPage();
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
      _notificationsFuture = _loadPage();
    });
  }

  Future<NotificationPage> _loadPage() async {
    final api = _api;
    if (api != null) {
      if (_filter == NotificationFilter.alerts) {
        // Alert filtering is local because the current API contract exposes
        // only isRead. Fetch all pages before slicing the alert result.
        final all = await _fetchAllPages(api);
        final alerts = all.where((item) => item.isAlert).toList();
        _total = alerts.length;
        final start = (_page - 1) * _pageSize;
        final items = start >= alerts.length
            ? const <AppNotification>[]
            : alerts.skip(start).take(_pageSize).toList();
        return NotificationPage(items: items, total: _total);
      }
      final result = await api.fetch(
        pageIndex: _page,
        pageSize: _pageSize,
        isRead: _filter == NotificationFilter.unread ? false : null,
      );
      _total = result.total;
      return result;
    }

    final items = [...await _repository.getNotifications()];
    items.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    _total = items.length;
    return NotificationPage(items: items, total: items.length);
  }

  Future<List<AppNotification>> _fetchAllPages(
    ApiNotificationsRepository api,
  ) async {
    final first = await api.fetch(pageIndex: 1, pageSize: _pageSize);
    final items = [...first.items];
    final pages = (first.total + _pageSize - 1) ~/ _pageSize;
    for (var page = 2; page <= pages; page++) {
      final next = await api.fetch(pageIndex: page, pageSize: _pageSize);
      items.addAll(next.items);
    }
    return items;
  }

  int get _totalPages =>
      _total <= 0 ? 1 : ((_total + _pageSize - 1) ~/ _pageSize);

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _page) return;
    setState(() {
      _page = page;
      _notificationsFuture = _loadPage();
    });
  }

  Future<void> _refreshNotifications() async {
    _reload();
    await _notificationsFuture;
  }

  Future<void> _onTap(AppNotification notification) async {
    if (_openingNotification) return;
    _openingNotification = true;
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
    await _showNotificationDetail(notification.copyWith(isRead: true));
    _openingNotification = false;
  }

  Future<void> _showNotificationDetail(AppNotification notification) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  notification.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(notification.message),
                const SizedBox(height: 12),
                Text('Thời gian: ${notification.timeAgo}'),
                Text('Loại: ${notification.type.name}'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppGradientHeader(
          title: 'Cảnh báo kho',
          subtitle: 'Thông báo & cảnh báo tồn kho',
          trailing: IconButton(
            onPressed: _reload,
            color: Colors.white,
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<NotificationPage>(
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
              final notifications = snapshot.data?.items ?? const [];
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
                  itemCount: visible.isEmpty
                      ? 2
                      : visible.length + 1 + (_totalPages > 1 ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return NotificationsFilterChips(
                        selectedFilter: _filter,
                        unreadCount: unreadCount,
                        alertCount: alertCount,
                        onChanged: (filter) {
                          setState(() {
                            _filter = filter;
                            _page = 1;
                            _notificationsFuture = _loadPage();
                          });
                        },
                      );
                    }
                    if (visible.isEmpty) {
                      return const HEmptyState(
                        title: 'Không có thông báo phù hợp',
                        description: 'Hãy thử chọn bộ lọc khác.',
                        icon: Icons.notifications_none,
                      );
                    }
                    if (_totalPages > 1 && index == visible.length + 1) {
                      return NotificationsPager(
                        page: _page,
                        totalPages: _totalPages,
                        onChanged: _goToPage,
                      );
                    }
                    final notification = visible[index - 1];
                    return NotificationsCard(
                      notification: notification,
                      onTap: () => _onTap(notification),
                      onDismissed: _reload,
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
