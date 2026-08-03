import 'package:flutter/material.dart';

import '../models/warehouse_report.dart';

/// Lớp giao diện (Interface) định nghĩa phương thức lấy thông tin báo cáo kho hàng.
abstract class WarehouseReportRepository {
  /// Lấy dữ liệu báo cáo tổng quan của kho hàng.
  Future<WarehouseReport> getWarehouseReport();
}

/// Lớp giả lập (Mock) của [WarehouseReportRepository] phục vụ thiết kế giao diện và chạy thử nghiệm.
class MockWarehouseReportRepository implements WarehouseReportRepository {
  /// Lấy thông tin báo cáo kho hàng giả lập sau một khoảng trễ ngắn.
  @override
  Future<WarehouseReport> getWarehouseReport() async {
    // API_SWAP: Thay thế phản hồi giả lập này bằng cuộc gọi API GET /reports/warehouse-overview thực tế.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return const WarehouseReport(
      warehouseName: 'Kho A',
      periodLabel: 'Tháng 7/2025',
      totalThuMua: 355,
      totalGiaoHang: 308,
      totalStockLabel: '1.6k',
      weeklyActivities: [
        WeeklyWarehouseActivity(dayLabel: 'T2', inbound: 42, outbound: 15),
        WeeklyWarehouseActivity(dayLabel: 'T3', inbound: 55, outbound: 18),
        WeeklyWarehouseActivity(dayLabel: 'T4', inbound: 38, outbound: 28),
        WeeklyWarehouseActivity(dayLabel: 'T5', inbound: 62, outbound: 20),
        WeeklyWarehouseActivity(dayLabel: 'T6', inbound: 46, outbound: 18),
        WeeklyWarehouseActivity(dayLabel: 'T7', inbound: 69, outbound: 24),
        WeeklyWarehouseActivity(dayLabel: 'CN', inbound: 36, outbound: 12),
      ],
      topThuMuaProducts: [
        TopThuMuaProduct(
          name: 'Cáp sạc Type-C 1m',
          quantity: 150,
          color: Color(0xFF16B957),
        ),
        TopThuMuaProduct(
          name: 'Tai nghe bluetooth',
          quantity: 80,
          color: Color(0xFF3478F6),
        ),
        TopThuMuaProduct(
          name: 'Bóng đèn LED 9W',
          quantity: 50,
          color: Color(0xFFA855F7),
        ),
      ],
    );
  }
}
