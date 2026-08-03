import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/warehouse_report.dart';

/// Thẻ hiển thị biểu đồ hoạt động xuất nhập kho hàng tuần (Weekly Activity Chart Card).
/// Sử dụng các cột dọc (Row/Column) mô phỏng dạng biểu đồ Bar Chart so sánh hoạt động Nhập/Xuất kho hàng ngày.
class WeeklyActivityChartCard extends StatelessWidget {
  /// Khởi tạo [WeeklyActivityChartCard] nhận danh sách hoạt động trong tuần.
  const WeeklyActivityChartCard({
    required this.activities,
    super.key,
  });

  /// Danh sách dữ liệu hoạt động các ngày trong tuần.
  final List<WeeklyWarehouseActivity> activities;

  @override
  Widget build(BuildContext context) {
    // Tìm giá trị lớn nhất của nhập/xuất để làm đỉnh trục Y
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
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề biểu đồ và chú thích màu sắc (Legend)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nhập / Xuất tuần này',
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const _LegendDot(color: AppColors.primary, label: 'Nhập'),
              const SizedBox(width: 10),
              const _LegendDot(color: Color(0xFF93C5FD), label: 'Xuất'),
            ],
          ),
          const SizedBox(height: 14),
          // Khu vực vẽ biểu đồ (Trục Y bên trái, Cột bên phải)
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

/// Nhãn giá trị chia vạch dọc theo trục Y (_YAxisLabels).
class _YAxisLabels extends StatelessWidget {
  const _YAxisLabels({
    required this.maxValue,
  });

  /// Giá trị lớn nhất của biểu đồ.
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
              style: TextStyle(
                color: AppColors.textSecondaryFor(context),
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

/// Cột biểu đồ của một ngày đơn lẻ (_ChartDayColumn) gồm hai thanh nhập/xuất và nhãn ngày phía dưới.
class _ChartDayColumn extends StatelessWidget {
  const _ChartDayColumn({
    required this.activity,
    required this.maxValue,
  });

  /// Hoạt động trong ngày đó.
  final WeeklyWarehouseActivity activity;

  /// Giá trị lớn nhất trên biểu đồ để làm mốc tỷ lệ chiều cao.
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
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thanh cột dọc riêng lẻ (_Bar) hiển thị dữ liệu nhập hoặc xuất.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.color,
  });

  /// Chiều cao của cột.
  final double height;

  /// Màu sắc của cột.
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

/// Chấm ghi chú màu sắc bên góc phải biểu đồ (_LegendDot).
class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  /// Màu sắc của chấm.
  final Color color;

  /// Nhãn văn bản đi kèm.
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
          style: TextStyle(
            color: AppColors.textSecondaryFor(context),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
