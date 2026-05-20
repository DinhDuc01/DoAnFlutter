import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/quick_action.dart';

class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key});

  static const actions = [
    QuickAction(
      title: 'Nhập kho',
      icon: Icons.inventory_2_outlined,
      color: AppColors.primary,
      route: AppRoutes.inbound,
    ),
    QuickAction(
      title: 'Xuất kho',
      icon: Icons.local_shipping_outlined,
      color: Color(0xFF3B82F6),
      route: AppRoutes.outbound,
    ),
    QuickAction(
      title: 'Kiểm kho',
      icon: Icons.assignment_outlined,
      color: Color(0xFF8B5CF6),
      route: AppRoutes.inventory,
    ),
    QuickAction(
      title: 'Quét QR',
      icon: Icons.qr_code_scanner,
      color: Color(0xFFF59E0B),
      route: AppRoutes.scanQr,
    ),
    QuickAction(
      title: 'Thống kê',
      icon: Icons.bar_chart,
      color: Color(0xFF06B6D4),
      route: AppRoutes.reports,
    ),
    QuickAction(
      title: 'Lịch sử',
      icon: Icons.history,
      color: Color(0xFFEC4899),
      route: AppRoutes.history,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final item = actions[index];

        return InkWell(
          onTap: () => Navigator.of(context).pushNamed(item.route),
          borderRadius: BorderRadius.circular(14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
