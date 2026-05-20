class InventoryCheck {
  const InventoryCheck({
    required this.checkCode,
    required this.warehouseName,
    required this.noteHint,
    required this.items,
  });

  final String checkCode;
  final String warehouseName;
  final String noteHint;
  final List<InventoryCheckItem> items;
}

class InventoryCheckItem {
  const InventoryCheckItem({
    required this.productName,
    required this.sku,
    required this.systemQuantity,
    this.actualQuantity,
  });

  final String productName;
  final String sku;
  final int systemQuantity;
  final int? actualQuantity;

  int? get difference {
    if (actualQuantity == null) return null;
    return actualQuantity! - systemQuantity;
  }

  InventoryCheckItem copyWith({
    int? actualQuantity,
    bool clearActualQuantity = false,
  }) {
    return InventoryCheckItem(
      productName: productName,
      sku: sku,
      systemQuantity: systemQuantity,
      actualQuantity: clearActualQuantity ? null : actualQuantity ?? this.actualQuantity,
    );
  }
}
