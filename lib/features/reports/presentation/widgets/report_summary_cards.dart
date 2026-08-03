import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/warehouse_report.dart';

/// Widget hàng chứa các thẻ tóm tắt báo cáo (Report Summary Cards) gồm: Tổng nhập, Tổng xuất, Tồn kho.
class ReportSummaryCards extends StatelessWidget {
  /// Khởi tạo [ReportSummaryCards] nhận thông tin báo cáo.
  const ReportSummaryCards({
    required this.report,
    super.key,
  });

  /// Dữ liệu báo cáo tổng quan kho.
  final WarehouseReport report;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Thẻ tóm tắt tổng số lượng nhập kho
        Expanded(
          child: _SummaryCard(
            icon: Icons.trending_up,
            iconColor: AppColors.primary,
            value: report.totalThuMua.toString(),
            label: 'Tổng nhập',
          ),
        ),
        const SizedBox(width: 8),
        // Thẻ tóm tắt tổng số lượng xuất kho
        Expanded(
          child: _SummaryCard(
            icon: Icons.trending_down,
            iconColor: const Color(0xFF3478F6),
            value: report.totalGiaoHang.toString(),
            label: 'Tổng xuất',
          ),
        ),
        const SizedBox(width: 8),
        // Thẻ tóm tắt tổng lượng tồn kho
        Expanded(
          child: _SummaryCard(
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFFA855F7),
            value: report.totalStockLabel,
            label: 'Tồn kho',
          ),
        ),
      ],
    );
  }
}

/// Thẻ tóm tắt đơn lẻ (_SummaryCard) hiển thị một Icon, giá trị số liệu và nhãn tương ứng.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  /// Biểu tượng Icon của thẻ.
  final IconData icon;

  /// Màu sắc đặc trưng của biểu tượng và màu nền mờ.
  final Color iconColor;

  /// Giá trị số liệu của thẻ báo cáo.
  final String value;

  /// Nhãn văn bản của thẻ báo cáo.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Vòng tròn chứa Icon
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          // Giá trị số liệu
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimaryFor(context),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          // Nhãn tên thẻ
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
