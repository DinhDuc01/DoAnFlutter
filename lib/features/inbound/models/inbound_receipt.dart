class InboundReceipt {
  const InboundReceipt({
    required this.status,
    required this.productName,
    required this.sku,
    required this.currentStock,
    required this.receiptCode,
    required this.weightKg,
    required this.quantity,
    required this.noteHint,
  });

  final String status;
  final String productName;
  final String sku;
  final int currentStock;
  final String receiptCode;
  final double weightKg;
  final int quantity;
  final String noteHint;
}

class InboundSuccessResult {
  const InboundSuccessResult({
    required this.receiptCode,
    required this.quantity,
    required this.productName,
    required this.sku,
    required this.warehouseName,
    required this.performedBy,
    required this.completedAt,
  });

  final String receiptCode;
  final int quantity;
  final String productName;
  final String sku;
  final String warehouseName;
  final String performedBy;
  final DateTime completedAt;
}
