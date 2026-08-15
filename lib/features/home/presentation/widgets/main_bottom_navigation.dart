import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../notifications/presentation/widgets/notification_bell_icon.dart';

enum HomeSection {
  home,
  purchase,
  warehouse,
  outbound,
  notifications,
  account,
}

/// Thanh điều hướng chính cho sáu khu vực của app.
///
/// Style (màu chọn/không chọn, cỡ nhãn) lấy từ `bottomNavigationBarTheme` trong
/// AppTheme để đồng bộ toàn app; ở đây chỉ bổ sung viền trên + bóng nhẹ.
class MainBottomNavigation extends StatelessWidget {
  const MainBottomNavigation({
    required this.currentIndex,
    required this.onTap,
    this.sections = HomeSection.values,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<HomeSection> sections;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        border: Border(
          top: BorderSide(color: AppColors.borderFor(context), width: 1),
        ),
        boxShadow: AppColors.isDark(context)
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 12,
                  offset: Offset(0, -3),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          onTap: onTap,
          items: [
            for (final section in sections) _item(section),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _item(HomeSection section) {
    return switch (section) {
      HomeSection.home => const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_rounded),
          label: 'Trang chủ',
        ),
      HomeSection.purchase => const BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart_outlined),
          activeIcon: Icon(Icons.shopping_cart_rounded),
          label: 'Thu mua',
        ),
      HomeSection.warehouse => const BottomNavigationBarItem(
          icon: Icon(Icons.warehouse_outlined),
          activeIcon: Icon(Icons.warehouse_rounded),
          label: 'Kho',
        ),
      HomeSection.outbound => const BottomNavigationBarItem(
          icon: Icon(Icons.local_shipping_outlined),
          activeIcon: Icon(Icons.local_shipping_rounded),
          label: 'Xuất kho',
        ),
      HomeSection.notifications => const BottomNavigationBarItem(
          icon: NotificationBellIcon(icon: Icons.notifications_outlined),
          activeIcon: NotificationBellIcon(icon: Icons.notifications_rounded),
          label: 'Thông báo',
        ),
      HomeSection.account => const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          activeIcon: Icon(Icons.person_rounded),
          label: 'Tôi',
        ),
    };
  }
}
