import 'package:flutter/material.dart';

enum OperationHistoryType {
  inbound,
  outbound,
  inventory,
}

class OperationHistory {
  const OperationHistory({
    required this.type,
    required this.productName,
    required this.sku,
    required this.referenceCode,
    required this.quantityChange,
    required this.createdAt,
  });

  final OperationHistoryType type;
  final String productName;
  final String sku;
  final String referenceCode;
  final int quantityChange;
  final DateTime createdAt;

  String get typeLabel {
    return switch (type) {
      OperationHistoryType.inbound => 'Nhập kho',
      OperationHistoryType.outbound => 'Xuất kho',
      OperationHistoryType.inventory => 'Kiểm kho',
    };
  }

  IconData get icon {
    return switch (type) {
      OperationHistoryType.inbound => Icons.inventory_2_outlined,
      OperationHistoryType.outbound => Icons.local_shipping_outlined,
      OperationHistoryType.inventory => Icons.assignment_outlined,
    };
  }

  Color get color {
    return switch (type) {
      OperationHistoryType.inbound => const Color(0xFF16B957),
      OperationHistoryType.outbound => const Color(0xFFFB2C36),
      OperationHistoryType.inventory => const Color(0xFFA855F7),
    };
  }
}
