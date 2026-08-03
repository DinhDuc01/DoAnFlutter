import 'package:flutter/material.dart';

/// Các loại hoạt động kho hàng được ghi lại trong lịch sử.
enum OperationHistoryType {
  /// Nhập kho (Inbound)
  inbound,

  /// Xuất kho (Outbound)
  outbound,

  /// Kiểm kê tồn kho.
  inventory,

  /// Các thao tác hệ thống khác của người dùng.
  other,
}

/// Đại diện cho một bản ghi lịch sử hoạt động kho hàng (Operation History).
class OperationHistory {
  /// Khởi tạo [OperationHistory] với các thông số bắt buộc.
  const OperationHistory({
    required this.type,
    required this.productName,
    required this.sku,
    required this.referenceCode,
    required this.quantityChange,
    required this.createdAt,
  });

  /// Loại hoạt động (nhập, xuất, kiểm kê).
  final OperationHistoryType type;

  /// Tên sản phẩm chịu tác động của hoạt động.
  final String productName;

  /// Mã định danh sản phẩm (SKU).
  final String sku;

  /// Mã tham chiếu của phiếu liên quan (phiếu nhập, phiếu xuất, phiếu kiểm).
  final String referenceCode;

  /// Lượng thay đổi số lượng (dương là tăng, âm là giảm).
  final int quantityChange;

  /// Thời gian tạo bản ghi hoạt động.
  final DateTime createdAt;

  /// Trả về nhãn tiếng Việt tương ứng với loại hoạt động.
  String get typeLabel {
    return switch (type) {
      OperationHistoryType.inbound => 'Nhập kho',
      OperationHistoryType.outbound => 'Xuất kho',
      OperationHistoryType.inventory => 'Kiểm kê',
      OperationHistoryType.other => 'Thao tác',
    };
  }

  /// Trả về biểu tượng Icon tương ứng cho hoạt động.
  IconData get icon {
    return switch (type) {
      OperationHistoryType.inbound => Icons.inventory_2_outlined,
      OperationHistoryType.outbound => Icons.local_shipping_outlined,
      OperationHistoryType.inventory => Icons.assignment_outlined,
      OperationHistoryType.other => Icons.history,
    };
  }

  /// Trả về màu sắc đại diện cho loại hoạt động đó.
  Color get color {
    return switch (type) {
      OperationHistoryType.inbound => const Color(0xFF16B957),
      OperationHistoryType.outbound => const Color(0xFFFB2C36),
      OperationHistoryType.inventory => const Color(0xFFA855F7),
      OperationHistoryType.other => const Color(0xFF2563EB),
    };
  }
}
