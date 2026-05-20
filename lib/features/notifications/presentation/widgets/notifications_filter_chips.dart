import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/app_notification.dart';

class NotificationsFilterChips extends StatelessWidget {
  const NotificationsFilterChips({
    required this.selectedFilter,
    required this.unreadCount,
    required this.onChanged,
    super.key,
  });

  final NotificationFilter selectedFilter;
  final int unreadCount;
  final ValueChanged<NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FilterChipButton(
            label: 'Tất cả',
            isSelected: selectedFilter == NotificationFilter.all,
            onTap: () => onChanged(NotificationFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Chưa đọc',
            badge: unreadCount,
            isSelected: selectedFilter == NotificationFilter.unread,
            onTap: () => onChanged(NotificationFilter.unread),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Cảnh báo',
            isSelected: selectedFilter == NotificationFilter.alerts,
            onTap: () => onChanged(NotificationFilter.alerts),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (badge != null && badge! > 0) ...[
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
