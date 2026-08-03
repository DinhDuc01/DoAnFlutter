import 'package:flutter/material.dart';

/// Đại diện cho dữ liệu báo cáo tổng quan kho hàng (Warehouse Report).
class WarehouseReport {
  /// Khởi tạo [WarehouseReport] với các trường báo cáo bắt buộc.
  const WarehouseReport({
    required this.warehouseName,
    required this.periodLabel,
    required this.totalThuMua,
    required this.totalGiaoHang,
    required this.totalStockLabel,
    required this.weeklyActivities,
    required this.topThuMuaProducts,
  });

  /// Tên kho hàng được làm báo cáo.
  final String warehouseName;

  /// Nhãn hiển thị chu kỳ báo cáo (VD: Tháng 7/2025).
  final String periodLabel;

  /// Tổng số sản phẩm đã nhập kho.
  final int totalThuMua;

  /// Tổng số sản phẩm đã xuất kho.
  final int totalGiaoHang;

  /// Nhãn hiển thị tổng lượng tồn kho dạng rút gọn (VD: 1.6k).
  final String totalStockLabel;

  /// Hoạt động hàng tuần của kho hàng.
  final List<WeeklyWarehouseActivity> weeklyActivities;

  /// Danh sách sản phẩm nhập kho nhiều nhất (Top nhập kho).
  final List<TopThuMuaProduct> topThuMuaProducts;
}

/// Chứa thông số hoạt động xuất nhập kho hàng tuần theo từng ngày.
class WeeklyWarehouseActivity {
  /// Khởi tạo [WeeklyWarehouseActivity].
  const WeeklyWarehouseActivity({
    required this.dayLabel,
    required this.inbound,
    required this.outbound,
  });

  /// Nhãn ngày trong tuần (VD: T2, T3, T4...).
  final String dayLabel;

  /// Lượng sản phẩm nhập vào trong ngày.
  final int inbound;

  /// Lượng sản phẩm xuất ra trong ngày.
  final int outbound;
}

/// Thông tin về sản phẩm thuộc nhóm nhập kho nhiều nhất.
class TopThuMuaProduct {
  /// Khởi tạo [TopThuMuaProduct].
  const TopThuMuaProduct({
    required this.name,
    required this.quantity,
    required this.color,
  });

  /// Tên sản phẩm.
  final String name;

  /// Số lượng đã nhập kho.
  final int quantity;

  /// Màu sắc đại diện cho sản phẩm trên biểu đồ.
  final Color color;
}
