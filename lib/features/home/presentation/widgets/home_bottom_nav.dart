import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BottomNavigationBar(
      currentIndex: 0,
      backgroundColor: colorScheme.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      onTap: (index) {
        if (index == 1) {
          Navigator.of(context).pushNamed(AppRoutes.notifications);
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
