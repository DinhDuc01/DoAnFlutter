import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/warehouse_report.dart';

class WeeklyActivityChartCard extends StatelessWidget {
  const WeeklyActivityChartCard({
    required this.activities,
    super.key,
  });

  final List<WeeklyWarehouseActivity> activities;

  @override
  Widget build(BuildContext context) {
    final maxValue = activities.fold<int>(
      1,
      (max, item) => [
        max,
        item.inbound,
        item.outbound,
      ].reduce((a, b) => a > b ? a : b),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Nhập / Xuất tuần này',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _LegendDot(color: AppColors.primary, label: 'Nhập'),
              SizedBox(width: 10),
              _LegendDot(color: Color(0xFF93C5FD), label: 'Xuất'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 135,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _YAxisLabels(maxValue: maxValue),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final item in activities)
                        _ChartDayColumn(
                          activity: item,
                          maxValue: maxValue,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YAxisLabels extends StatelessWidget {
  const _YAxisLabels({
    required this.maxValue,
  });

  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final step = (maxValue / 4).ceil();
    return SizedBox(
      width: 24,
      height: 110,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 4; i >= 0; i--)
            Text(
              '${step * i}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartDayColumn extends StatelessWidget {
  const _ChartDayColumn({
    required this.activity,
    required this.maxValue,
  });

  final WeeklyWarehouseActivity activity;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final inboundHeight = 90 * activity.inbound / maxValue;
    final outboundHeight = 90 * activity.outbound / maxValue;

    return SizedBox(
      width: 28,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Bar(
                  height: inboundHeight,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 3),
                _Bar(
                  height: outboundHeight,
                  color: const Color(0xFF93C5FD),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            activity.dayLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.color,
  });

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: height.clamp(4, 90),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
