import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/warehouse_report.dart';

class ReportSummaryCards extends StatelessWidget {
  const ReportSummaryCards({
    required this.report,
    super.key,
  });

  final WarehouseReport report;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.trending_up,
            iconColor: AppColors.primary,
            value: report.totalInbound.toString(),
            label: 'Tổng nhập',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            icon: Icons.trending_down,
            iconColor: const Color(0xFF3478F6),
            value: report.totalOutbound.toString(),
            label: 'Tổng xuất',
          ),
        ),
        const SizedBox(width: 8),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
        children: [
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
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
