class OutboundReceipt {
  const OutboundReceipt({
    required this.status,
    required this.productName,
    required this.sku,
    required this.currentStock,
    required this.receiptCode,
    required this.customerName,
    required this.quantity,
    required this.noteHint,
  });

  final String status;
  final String productName;
  final String sku;
  final int currentStock;
  final String receiptCode;
  final String customerName;
  final int quantity;
  final String noteHint;
}

class OutboundSuccessResult {
  const OutboundSuccessResult({
    required this.receiptCode,
    required this.quantity,
    required this.productName,
    required this.sku,
    required this.customerName,
    required this.performedBy,
    required this.completedAt,
  });

  final String receiptCode;
  final int quantity;
  final String productName;
  final String sku;
  final String customerName;
  final String performedBy;
  final DateTime completedAt;
}
