import 'package:flutter/material.dart';

import '../models/warehouse_report.dart';

abstract class WarehouseReportRepository {
  Future<WarehouseReport> getWarehouseReport();
}

class MockWarehouseReportRepository implements WarehouseReportRepository {
  @override
  Future<WarehouseReport> getWarehouseReport() async {
    // API_SWAP: Replace this mock response with GET /reports/warehouse-overview.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return const WarehouseReport(
      warehouseName: 'Kho A',
      periodLabel: 'Tháng 7/2025',
      totalInbound: 355,
      totalOutbound: 308,
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
      topInboundProducts: [
        TopInboundProduct(
          name: 'Cáp sạc Type-C 1m',
          quantity: 150,
          color: Color(0xFF16B957),
        ),
        TopInboundProduct(
          name: 'Tai nghe bluetooth',
          quantity: 80,
          color: Color(0xFF3478F6),
        ),
        TopInboundProduct(
          name: 'Bóng đèn LED 9W',
          quantity: 50,
          color: Color(0xFFA855F7),
        ),
      ],
    );
  }
}
