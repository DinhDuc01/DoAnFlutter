import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api_notifications_repository.dart';
import '../../data/notification_center.dart';
import '../../data/notification_navigator.dart';
import '../../data/notifications_repository.dart';
import '../../models/app_notification.dart';
import '../widgets/notifications_bottom_bar.dart';
import '../widgets/notifications_card.dart';
import '../widgets/notifications_filter_chips.dart';
import '../widgets/notifications_header.dart';
import '../widgets/notifications_pager.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({this.repository, super.key});

  final NotificationsRepository? repository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const int _pageSize = 10;

  late final NotificationsRepository _repository;
  List<AppNotification> _notifications = const [];
  NotificationFilter _filter = NotificationFilter.all;
  bool _isLoading = true;
  String? _error;
  int _loadGeneration = 0;

  int _page = 1;
  int _total = 0;

  StreamSubscription<void>? _refreshSub;

  /// Chỉ có API thật mới hỗ trợ phân trang + đổi trạng thái. Test tiêm repo giả
  /// (chỉ có getNotifications) nên các thao tác này sẽ chạy cục bộ (optimistic).
  ApiNotificationsRepository? get _api =>
      _repository is ApiNotificationsRepository
          ? _repository as ApiNotificationsRepository
          : null;

  bool? get _serverIsReadFilter =>
      _filter == NotificationFilter.unread ? false : null;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiNotificationsRepository();
    // Tự tải lại khi có thông báo đẩy realtime (chỉ hiệu lực ở app thật).
    _refreshSub = NotificationCenter.instance.onRefresh.listen((_) {
      if (mounted) _loadNotifications(showLoading: false);
    });
    unawaited(_loadNotifications(showLoading: true));
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications({required bool showLoading}) async {
    final generation = ++_loadGeneration;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final api = _api;
      List<AppNotification> items;
      int total;
      if (api != null) {
        final page = await api.fetch(
          pageIndex: _page,
          pageSize: _pageSize,
          isRead: _serverIsReadFilter,
        );
        items = page.items;
        total = page.total;
      } else {
        items = await _repository.getNotifications();
        total = items.length;
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _notifications = items;
        _total = total;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  void _replaceItem(AppNotification updated) {
    setState(() {
      _notifications = [
        for (final n in _notifications)
          if (n.id == updated.id) updated else n,
      ];
    });
  }

  void _removeItemLocal(String id) {
    setState(() {
      _notifications = [
        for (final n in _notifications)
          if (n.id != id) n,
      ];
      if (_total > 0) _total -= 1;
    });
  }

  /// Bấm vào thông báo: đánh dấu đã đọc rồi điều hướng tới màn liên quan.
  /// Nếu không có màn liên quan thì chỉ đổi trạng thái, không chuyển trang.
  Future<void> _onTapNotification(AppNotification notification) async {
    if (!notification.isRead) {
      _replaceItem(notification.copyWith(isRead: true));
      final api = _api;
      if (api != null) {
        try {
          await api.markRead(notification.numericId);
          await NotificationCenter.instance.refreshUnread();
        } catch (_) {
          // Bỏ qua: UI đã cập nhật optimistic.
        }
      }
    }

    final route = NotificationNavigator.routeFor(notification.directionId);
    if (route != null && mounted) {
      await Navigator.of(context).pushNamed(route);
    }
  }

  Future<void> _dismissNotification(AppNotification notification) async {
    _removeItemLocal(notification.id);
    final api = _api;
    if (api != null) {
      try {
        await api.delete(notification.numericId);
        await NotificationCenter.instance.refreshUnread();
      } catch (_) {
        // Bỏ qua lỗi xoá phía server.
      }
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      _notifications = [
        for (final n in _notifications) n.copyWith(isRead: true),
      ];
    });
    final api = _api;
    if (api != null) {
      try {
        await api.markAllRead();
        await NotificationCenter.instance.refreshUnread();
      } catch (_) {
        // Bỏ qua lỗi.
      }
    }
  }

  void _onFilterChanged(NotificationFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _page = 1;
    });
    _loadNotifications(showLoading: false);
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _page) return;
    setState(() => _page = page);
    _loadNotifications(showLoading: true);
  }

  int get _totalPages =>
      _total <= 0 ? 1 : ((_total + _pageSize - 1) ~/ _pageSize);

  List<AppNotification> get _filteredNotifications {
    return switch (_filter) {
      NotificationFilter.all => _notifications,
      NotificationFilter.unread => [
          for (final n in _notifications)
            if (!n.isRead) n,
        ],
      NotificationFilter.alerts => [
          for (final n in _notifications)
            if (n.isAlert) n,
        ],
    };
  }

  int get _unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NotificationsHeader(
              unreadCount: _unreadCount,
              onMarkAllAsRead: _markAllAsRead,
            ),
            NotificationsFilterChips(
              selectedFilter: _filter,
              unreadCount: _unreadCount,
              onChanged: _onFilterChanged,
            ),
            if (!_isLoading)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () => _loadNotifications(showLoading: false),
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Tải lại thông báo',
                  ),
                ),
              ),
            Expanded(child: _buildContent()),
            if (!_isLoading && _error == null && _totalPages > 1)
              NotificationsPager(
                page: _page,
                totalPages: _totalPages,
                onChanged: _goToPage,
              ),
          ],
        ),
      ),
      bottomNavigationBar: const NotificationsBottomBar(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Không tải được thông báo',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _loadNotifications(showLoading: true),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredNotifications;
    if (filtered.isEmpty) {
      return const Center(child: Text('Không có thông báo phù hợp'));
    }

    return RefreshIndicator(
      onRefresh: () => _loadNotifications(showLoading: false),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final notification = filtered[index];
          return NotificationsCard(
            notification: notification,
            onTap: () => _onTapNotification(notification),
            onDismissed: () => _dismissNotification(notification),
          );
        },
      ),
    );
  }
}
