import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api_notifications_repository.dart';
import '../../data/notifications_repository.dart';
import '../../models/app_notification.dart';
import '../widgets/notifications_bottom_bar.dart';
import '../widgets/notifications_card.dart';
import '../widgets/notifications_filter_chips.dart';
import '../widgets/notifications_header.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({this.repository, super.key});

  final NotificationsRepository? repository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsRepository _repository;
  List<AppNotification> _notifications = const [];
  NotificationFilter _filter = NotificationFilter.all;
  bool _isLoading = true;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiNotificationsRepository();
    unawaited(_loadNotifications(showLoading: true));
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
      final notifications = await _repository.getNotifications();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _notifications = notifications;
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

  void _removeNotification(String id) {
    setState(() {
      _notifications = [
        for (final notification in _notifications)
          if (notification.id != id) notification,
      ];
    });
  }

  void _markAllAsRead() {
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
              onChanged: (filter) => setState(() => _filter = filter),
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
            onDismissed: () => _removeNotification(notification.id),
          );
        },
      ),
    );
  }
}
