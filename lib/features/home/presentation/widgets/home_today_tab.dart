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
                'Tuấn Mây Mobile',
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
            'Việc cần làm hôm nay',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),

          // Các thẻ thống kê số lượng công việc (Thu mua, Giao, Cảnh báo)
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  label: 'Thu mua',
                  value: '4',
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatBox(
                  label: 'Bán',
                  value: '3',
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatBox(
                  label: 'Cảnh báo',
                  value: '2',
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
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
        const SizedBox(height: 20),

        // 3. Tiêu đề danh sách công việc
        _buildListHeader('Công việc trong ngày'),
        const SizedBox(height: 8),

        // 4. Danh sách công việc gom chung trong 1 Container thẻ màu trắng bo góc có chia Divider
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            children: [
              _buildScheduleItem(
                time: '08:00',
                title: 'Đi thu Nguyễn Văn An',
              ),
              const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Color(0xFFF1F5F9)),
              _buildScheduleItem(
                time: '10:00',
                title: 'Kiểm L1 / A03 ẩm cao',
              ),
              const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Color(0xFFF1F5F9)),
              _buildScheduleItem(
                time: '14:00',
                title: 'Giao đơn bán Phú Thịnh',
              ),
            ],
          ),
        ),
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
      child: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD97706),
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'L1 A03 cách ly - công nợ quá hạn',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Color(0xFFD97706),
            size: 18,
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
        'label': 'Kiểm chất',
        'icon': Icons.gpp_maybe_outlined,
        'color': const Color(0xFFEA580C),
        'route': AppRoutes.qualityInspection,
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

  Widget _buildListHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildScheduleItem({
    required String time,
    required String title,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF159447),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
