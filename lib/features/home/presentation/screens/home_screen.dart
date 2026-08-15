import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/home_today_tab.dart';
import '../../../thu_mua/presentation/widgets/thu_mua_tab.dart';
import '../../../kho/presentation/widgets/kho_tab.dart';
import '../../../outbound_orders/presentation/screens/outbound_order_list_screen.dart';
import '../../../notifications/presentation/widgets/notifications_tab.dart';
import '../../../account/presentation/widgets/account_tab.dart';
import '../widgets/main_bottom_navigation.dart';
import '../../../../core/widgets/permission_guard.dart';
import '../../../auth/data/auth_session_store.dart';

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
  bool _handlingBack = false;
  final GlobalKey<ThuMuaTabState> _thuMuaKey = GlobalKey<ThuMuaTabState>();

  late final List<Widget> _tabs;
  late final List<HomeSection> _sections;

  @override
  void initState() {
    super.initState();
    final session = AuthSessionStore.current;
    _sections = [
      HomeSection.home,
      if (session?.hasMenuAccess('RICE_PURCHASE') == true) HomeSection.purchase,
      if (session?.hasMenuAccess('INVENTORIES') == true) HomeSection.warehouse,
      if (session?.hasMenuAccess('OUTBOUND_ORDERS') == true)
        HomeSection.outbound,
      HomeSection.notifications,
      HomeSection.account,
    ];
    _currentIndex = _visibleIndexForLegacyIndex(widget.initialIndex);
    _tabs = [
      for (final section in _sections) _screenFor(section),
    ];
  }

  Widget _screenFor(HomeSection section) {
    return switch (section) {
      HomeSection.home => HomeTodayTab(
          onTabChanged: (index) {
            _selectLegacyIndex(index);
          },
        ),
      HomeSection.purchase => PermissionGuard(
          menuCode: 'RICE_PURCHASE',
          child: ThuMuaTab(key: _thuMuaKey),
        ),
      HomeSection.warehouse => const PermissionGuard(
          menuCode: 'INVENTORIES',
          child: KhoTab(),
        ),
      HomeSection.outbound => const PermissionGuard(
          menuCode: 'OUTBOUND_ORDERS',
          child: OutboundOrderListScreen(embedded: true),
        ),
      HomeSection.notifications => const NotificationsTab(),
      HomeSection.account => const AccountTab(),
    };
  }

  int _visibleIndexForLegacyIndex(int legacyIndex) {
    final section = HomeSection.values[legacyIndex.clamp(0, 5)];
    final visibleIndex = _sections.indexOf(section);
    return visibleIndex < 0 ? 0 : visibleIndex;
  }

  void _selectLegacyIndex(int legacyIndex) {
    final nextIndex = _visibleIndexForLegacyIndex(legacyIndex);
    setState(() => _currentIndex = nextIndex);
    if (_sections[nextIndex] == HomeSection.purchase) {
      _thuMuaKey.currentState?.refreshLatest();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _handlingBack || !mounted) return;
        if (_sections[_currentIndex] != HomeSection.home) {
          setState(() => _currentIndex = 0);
          return;
        }
        _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundFor(context),
        body: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
        ),
        bottomNavigationBar: MainBottomNavigation(
          currentIndex: _currentIndex,
          sections: _sections,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (_sections[index] == HomeSection.purchase) {
              _thuMuaKey.currentState?.refreshLatest();
            }
          },
        ),
      ),
    );
  }

  Future<void> _confirmExit() async {
    _handlingBack = true;
    try {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Thoát ứng dụng?'),
          content: const Text('Bạn có chắc muốn thoát StockLite không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Ở lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Thoát'),
            ),
          ],
        ),
      );
      if (shouldExit == true && mounted) {
        await SystemNavigator.pop();
      }
    } finally {
      _handlingBack = false;
    }
  }
}
