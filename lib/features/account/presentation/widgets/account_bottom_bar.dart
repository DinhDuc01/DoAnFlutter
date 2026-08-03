import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

/// Widget thanh điều hướng dưới cùng (Bottom Navigation Bar) riêng cho màn hình quản lý tài khoản.
class AccountBottomBar extends StatelessWidget {
  const AccountBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 2, // Đang ở tab Tài khoản (index 2)
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      onTap: (index) {
        // Xử lý chuyển tab khi chạm vào
        if (index == 0) {
          // Quay về Trang chủ và giải phóng stack điều hướng
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.home,
            (route) => false,
          );
        }
        if (index == 1) {
          // Chuyển sang màn hình Thông báo
          Navigator.of(context).pushNamed(AppRoutes.notifications);
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
