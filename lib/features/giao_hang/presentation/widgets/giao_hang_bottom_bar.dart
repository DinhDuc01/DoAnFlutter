import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

/// Widget BottomNavigationBar cho quy trình xuất kho (Outbound Bottom Bar).
class GiaoHangBottomBar extends StatelessWidget {
  const GiaoHangBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0, // Tab Trang chủ được chọn mặc định
      selectedItemColor: const Color(
          0xFF3478F6), // Màu xanh dương làm chủ đạo cho luồng xuất kho
      unselectedItemColor: AppColors.textSecondary,
      onTap: (index) {
        // Điều hướng sang các màn hình chính khác
        if (index == 0) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.home,
            (route) => false,
          );
        }
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
