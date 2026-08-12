import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';

class HomeTodayTab extends StatelessWidget {
  const HomeTodayTab({this.onTabChanged, super.key});

  final ValueChanged<int>? onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color:
          const Color(0xFFF4FBF7), // Nền xanh lá nhạt cho toàn bộ màn hình dưới
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Green Header Section
          _buildHeader(),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: _buildDataState(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF166534), // Màu xanh rừng đậm thống nhất
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dòng đầu: Tên App & Icon lá cây màu trắng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lúa gạo Tuấn Mây',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.eco_outlined,
                color: Colors.white.withValues(alpha: 0.9),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Tiêu đề chính
          const Text(
            'Trang chủ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thu mua, quản lý kho và xay xát lúa gạo',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Thẻ cảnh báo màu vàng
        _buildAlertBox(),
        const SizedBox(height: 16),

        // 2. Lưới phím tắt 6 tính năng
        _buildShortcutGrid(),
      ],
    );
  }

  Widget _buildAlertBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // Nền màu vàng cam nhạt
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Xem các mặt hàng và lô lúa sắp hết trong kho',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => onTabChanged?.call(4),
            icon: const Icon(
              Icons.chevron_right,
              color: Color(0xFFD97706),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutGrid() {
    // Cấu hình danh sách lưới phím tắt theo mockup Image 2
    final List<Map<String, dynamic>> items = [
      {
        'label': 'Thu mua',
        'icon': Icons.shopping_cart_outlined,
        'color': const Color(0xFF159447),
        'tabIndex': 1
      },
      {
        'label': 'Kho',
        'icon': Icons.warehouse_outlined,
        'color': const Color(0xFF2563EB),
        'tabIndex': 2
      },
      {
        'label': 'Bán / xuất kho',
        'icon': Icons.local_shipping_outlined,
        'color': const Color(0xFFDB2777),
        'tabIndex': 3
      },
      {
        'label': 'Xay xát',
        'icon': Icons.grain_outlined,
        'color': const Color(0xFFD97706),
        'route': AppRoutes.milling,
      },
      {
        'label': 'Kiểm kê',
        'icon': Icons.assignment_outlined,
        'color': const Color(0xFF7C3AED),
        'route': AppRoutes.stocktake,
      },
      {
        'label': 'Cân',
        'icon': Icons.scale_outlined,
        'color': const Color(0xFF0F766E),
        'route': AppRoutes.scale,
      },
      {
        'label': 'Công nợ',
        'icon': Icons.account_balance_wallet_outlined,
        'color': AppColors.warning,
        'route': AppRoutes.debts,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final route = item['route'] as String?;
                if (route != null) {
                  Navigator.of(context).pushNamed(route);
                  return;
                }

                final tabIndex = item['tabIndex'] as int?;
                if (tabIndex != null) {
                  onTabChanged?.call(tabIndex);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['label'] as String,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
