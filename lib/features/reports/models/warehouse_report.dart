import 'package:flutter/material.dart';

class WarehouseReport {
  const WarehouseReport({
    required this.warehouseName,
    required this.periodLabel,
    required this.totalInbound,
    required this.totalOutbound,
    required this.totalStockLabel,
    required this.weeklyActivities,
    required this.topInboundProducts,
  });

  final String warehouseName;
  final String periodLabel;
  final int totalInbound;
  final int totalOutbound;
  final String totalStockLabel;
  final List<WeeklyWarehouseActivity> weeklyActivities;
  final List<TopInboundProduct> topInboundProducts;
}

class WeeklyWarehouseActivity {
  const WeeklyWarehouseActivity({
    required this.dayLabel,
    required this.inbound,
    required this.outbound,
  });

  final String dayLabel;
  final int inbound;
  final int outbound;
}

class TopInboundProduct {
  const TopInboundProduct({
    required this.name,
    required this.quantity,
    required this.color,
  });

  final String name;
  final int quantity;
  final Color color;
}
