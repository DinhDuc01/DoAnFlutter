import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/home_today_tab.dart';
import '../../../thu_mua/presentation/widgets/thu_mua_tab.dart';
import '../../../kho/presentation/widgets/kho_tab.dart';
import '../../../outbound_orders/presentation/screens/outbound_order_list_screen.dart';
import '../../../notifications/presentation/widgets/notifications_tab.dart';
import '../../../account/presentation/widgets/account_tab.dart';
import '../widgets/main_bottom_navigation.dart';

/// HomeScreen represents the unified 6-tab layout container for:
/// Trang chủ, Thu mua, Kho, Xuất kho & giao hàng, Thông báo, Tôi.
class HomeScreen extends StatefulWidget {
  const HomeScreen({this.initialIndex = 0, super.key})
      : assert(initialIndex >= 0 && initialIndex < 6);

  final int initialIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  final GlobalKey<ThuMuaTabState> _thuMuaKey = GlobalKey<ThuMuaTabState>();

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _tabs = [
      HomeTodayTab(
        onTabChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 1) _thuMuaKey.currentState?.refreshLatest();
        },
      ), // Index 0: Trang chủ
      ThuMuaTab(key: _thuMuaKey), // Index 1: Thu mua
      const KhoTab(), // Index 2: Kho
      // Index 3: Xuất kho & giao hàng (phiếu xuất từ đơn bán)
      const OutboundOrderListScreen(embedded: true),
      const NotificationsTab(), // Index 4: Thông báo
      const AccountTab(), // Index 5: Tôi
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: MainBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) _thuMuaKey.currentState?.refreshLatest();
        },
      ),
    );
  }
}
