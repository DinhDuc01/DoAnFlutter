import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/recent_activity.dart';

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({super.key});

  static const activities = [
    RecentActivity(
      title: 'Nhập kho',
      subtitle: 'SKU-0001 • 10 phút trước',
      amount: '+50',
      color: AppColors.primary,
    ),
    RecentActivity(
      title: 'Xuất kho',
      subtitle: 'SKU-0004 • 1 giờ trước',
      amount: '-30',
      color: Colors.red,
    ),
    RecentActivity(
      title: 'Kiểm kho',
      subtitle: 'SKU-0003 • 3 giờ trước',
      amount: '-5',
      color: Colors.red,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < activities.length; index++) ...[
            RecentActivityItem(activity: activities[index]),
            if (index < activities.length - 1)
              Divider(
                height: 1,
                color: colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class RecentActivityItem extends StatelessWidget {
  const RecentActivityItem({
    required this.activity,
    super.key,
  });

  final RecentActivity activity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: activity.color.withValues(alpha: 0.12),
        child: Icon(
          Icons.inventory_2_outlined,
          color: activity.color,
          size: 20,
        ),
      ),
      title: Text(
        activity.title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        activity.subtitle,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Text(
        activity.amount,
        style: TextStyle(
          color: activity.color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
