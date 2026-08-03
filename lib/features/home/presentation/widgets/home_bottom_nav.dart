import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

/// Widget thanh điều hướng dưới cùng (Bottom Navigation Bar) cho màn hình chính.
class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BottomNavigationBar(
      currentIndex: 0, // Đang ở tab Trang chủ (index 0)
      backgroundColor: colorScheme.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      onTap: (index) {
        // Chuyển màn hình khi người dùng chọn tab tương ứng
        if (index == 1) {
          Navigator.of(context)
              .pushNamed(AppRoutes.notifications); // Sang trang thông báo
        }
        if (index == 2) {
          Navigator.of(context)
              .pushNamed(AppRoutes.account); // Sang trang tài khoản
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
