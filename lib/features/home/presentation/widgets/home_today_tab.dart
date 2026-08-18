import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../auth/data/auth_session_store.dart';

/// Tab Trang chủ: header xanh gradient + banner cảnh báo + lưới phím tắt.
class HomeTodayTab extends StatelessWidget {
  const HomeTodayTab({this.onTabChanged, super.key});

  final ValueChanged<int>? onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppInfoBanner(
                    message: 'Xem các mặt hàng và lô lúa sắp hết trong kho',
                    tone: AppTone.warning,
                    icon: Icons.warning_amber_rounded,
                    onTap: () => onTabChanged?.call(4),
                  ),
                  const SizedBox(height: 18),
                  const AppSectionHeader(
                    title: 'Tác vụ nhanh',
                    icon: Icons.bolt_rounded,
                  ),
                  _shortcutGrid(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final name = AuthSessionStore.current?.user.fullName;
    final greeting = (name != null && name.trim().isNotEmpty)
        ? 'Xin chào, $name'
        : 'Lúa gạo Tuấn Mây';
    return AppGradientHeader(
      overline: greeting,
      title: 'Trang chủ',
      subtitle: 'Thu mua, quản lý kho và xay xát lúa gạo',
      trailing: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.eco_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _shortcutGrid(BuildContext context) {
    final session = AuthSessionStore.current;
    if (session == null) return const SizedBox.shrink();
    const items = <_Shortcut>[
      _Shortcut('Thu mua', Icons.shopping_cart_outlined, AppColors.primary,
          menuCode: 'RICE_PURCHASE', tabIndex: 1),
      _Shortcut('Kho', Icons.warehouse_outlined, AppColors.info,
          menuCode: 'INBOUND_ORDERS', tabIndex: 2),
      _Shortcut('Đơn bán', Icons.receipt_long_outlined, AppColors.info,
          menuCode: 'SALE_ORDERS', route: AppRoutes.salesOrders),
      _Shortcut('Xuất kho / giao', Icons.local_shipping_outlined,
          AppColors.accentPink,
          menuCode: 'OUTBOUND_ORDERS', tabIndex: 3),
      _Shortcut('Kiểm kê', Icons.assignment_outlined, AppColors.accentPurple,
          menuCode: 'STOCKTAKE', route: AppRoutes.stocktake),
      _Shortcut(
          'Lô & truy vết', Icons.account_tree_outlined, AppColors.accentTeal,
          menuCode: 'PADDY_LOTS', route: AppRoutes.paddyLots),
      _Shortcut(
          'Công nợ', Icons.account_balance_wallet_outlined, AppColors.warning,
          menuCode: 'DEBTS', route: AppRoutes.debts),
      _Shortcut('Chất lượng', Icons.science_outlined, AppColors.accentPurple,
          menuCode: 'QUALITY_INSPECTIONS', route: AppRoutes.qualityInspections),
      _Shortcut('Nhập kho', Icons.move_to_inbox_outlined, AppColors.primaryDark,
          menuCode: 'INBOUND_ORDERS', route: AppRoutes.inboundPutaway),
    ];

    final visibleItems =
        items.where((item) => session.hasMenuAccess(item.menuCode)).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.98,
      ),
      itemCount: visibleItems.length,
      itemBuilder: (context, index) {
        final item = visibleItems[index];
        return AppCard(
          key: ValueKey(item.route ?? item.label),
          radius: AppColors.radiusMd,
          padding: const EdgeInsets.all(10),
          onTap: () {
            if (item.route != null) {
              Navigator.of(context).pushNamed(item.route!);
            } else if (item.tabIndex != null) {
              onTabChanged?.call(item.tabIndex!);
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppColors.textPrimaryFor(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Shortcut {
  const _Shortcut(this.label, this.icon, this.color,
      {required this.menuCode, this.tabIndex, this.route});

  final String label;
  final IconData icon;
  final Color color;
  final String menuCode;
  final int? tabIndex;
  final String? route;
}
