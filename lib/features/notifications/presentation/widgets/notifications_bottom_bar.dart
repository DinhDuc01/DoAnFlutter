import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

/// Thanh điều hướng phía dưới cùng dành cho màn hình Thông báo (Notifications Bottom Bar).
class NotificationsBottomBar extends StatelessWidget {
  /// Khởi tạo [NotificationsBottomBar].
  const NotificationsBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BottomNavigationBar(
      currentIndex: 1,
      backgroundColor: colorScheme.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      onTap: (index) {
        if (index == 0) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.home,
            (route) => false,
          );
        }
        if (index == 2) {
          Navigator.of(context).pushNamed(AppRoutes.account);
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Trang chủ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          label: 'Thông báo',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Tài khoản',
        ),
      ],
    );
  }
}
