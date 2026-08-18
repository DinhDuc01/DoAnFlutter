import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/warehouse_report.dart';

/// Widget Header cho màn hình thống kê báo cáo kho hàng (Report Header).
/// Hiển thị tiêu đề, tên kho hàng và khoảng thời gian báo cáo với dải màu gradient xanh dương.
class ReportHeader extends StatelessWidget {
  /// Khởi tạo [ReportHeader] nhận thông tin báo cáo kho.
  const ReportHeader({
    required this.report,
    super.key,
  });

  /// Thông tin báo cáo kho hàng.
  final WarehouseReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thống kê kho',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // Tiêu đề chính của header
          const Text(
            'Tổng quan hoạt động',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          // Tên kho và chu kỳ báo cáo
          Text(
            '${report.warehouseName} — ${report.periodLabel}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
