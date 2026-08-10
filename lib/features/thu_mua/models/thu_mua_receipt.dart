/// Phieu nhap kho nhap, gom san pham va thong tin kho de cap nhat ton.
class ThuMuaReceipt {
  const ThuMuaReceipt({
    this.id,
    required this.productVariantId,
    required this.warehouseId,
    required this.warehouseName,
    required this.status,
    required this.productName,
    required this.sku,
    required this.currentStock,
    required this.receiptCode,
    required this.weightKg,
    required this.quantity,
    required this.noteHint,
    required this.unitCostPrice,
    this.supplier,
    this.expectedDate,
    this.scheduleId,
    this.riceVarietyId,
    this.actualWeightKg = 0,
    this.moisturePercent,
    this.paidAmount = 0,
  });

  final int? id;

  /// ID bien the san pham tren backend.
  final int productVariantId;

  /// ID kho nhan hang.
  final int warehouseId;

  /// Ten kho nhan hang.
  final String warehouseName;

  /// Trang thai phieu.
  final String status;

  /// Ten san pham can nhap kho.
  final String productName;

  /// Ma SKU san pham.
  final String sku;

  /// So luong ton hien tai truoc khi nhap.
  final int currentStock;

  /// Ma phieu nhap hien thi tren mobile.
  final String receiptCode;

  /// Khoi luong ly thuyet cua moi san pham, don vi kg.
  final double weightKg;

  /// So luong mac dinh tren form nhap kho.
  final int quantity;

  /// Goi y ghi chu.
  final String noteHint;
  final double unitCostPrice;
  final ThuMuaSupplier? supplier;
  final DateTime? expectedDate;
  final int? scheduleId;
  final int? riceVarietyId;
  final double actualWeightKg;
  final double? moisturePercent;
  final double paidAmount;

  ThuMuaReceipt copyWith({
    ThuMuaSupplier? supplier,
    DateTime? expectedDate,
    int? scheduleId,
    int? riceVarietyId,
    double? actualWeightKg,
    double? moisturePercent,
    double? paidAmount,
    double? unitCostPrice,
    int? warehouseId,
    String? warehouseName,
  }) {
    return ThuMuaReceipt(
      id: id,
      productVariantId: productVariantId,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      status: status,
      productName: productName,
      sku: sku,
      currentStock: currentStock,
      receiptCode: receiptCode,
      weightKg: weightKg,
      quantity: quantity,
      noteHint: noteHint,
      unitCostPrice: unitCostPrice ?? this.unitCostPrice,
      supplier: supplier ?? this.supplier,
      expectedDate: expectedDate ?? this.expectedDate,
      scheduleId: scheduleId ?? this.scheduleId,
      riceVarietyId: riceVarietyId ?? this.riceVarietyId,
      actualWeightKg: actualWeightKg ?? this.actualWeightKg,
      moisturePercent: moisturePercent ?? this.moisturePercent,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }
}

class ThuMuaSupplier {
  const ThuMuaSupplier({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;
}

class ThuMuaOrderSubmission {
  const ThuMuaOrderSubmission({
    required this.id,
    required this.code,
    required this.status,
  });

  final int id;
  final String code;
  final String status;
}

class ThuMuaDraftSummary {
  const ThuMuaDraftSummary({
    required this.id,
    required this.code,
    required this.farmerName,
    required this.riceVarietyName,
    required this.actualWeightKg,
    required this.bagCount,
    required this.createdAt,
    this.debtAmount = 0,
  });

  final int id;
  final String code;
  final String farmerName;
  final String riceVarietyName;
  final double actualWeightKg;
  final int bagCount;
  final DateTime createdAt;
  final double debtAmount;
}

/// Tóm tắt phiếu mua/nhập kho dùng cho lịch sử và phân loại trạng thái.
class ThuMuaReceiptSummary {
  const ThuMuaReceiptSummary({
    required this.id,
    required this.code,
    required this.farmerName,
    required this.riceVarietyName,
    required this.actualWeightKg,
    required this.storedWeightKg,
    required this.remainingWeightKg,
    required this.status,
    required this.isDraft,
    required this.isConfirmed,
    required this.isFullyStored,
    required this.createdAt,
    this.scheduleId,
  });

  final int id;
  final String code;
  final String farmerName;
  final String riceVarietyName;
  final double actualWeightKg;
  final double storedWeightKg;
  final double remainingWeightKg;
  final String status;
  final bool isDraft;
  final bool isConfirmed;
  final bool isFullyStored;
  final DateTime createdAt;
  final int? scheduleId;
}

/// Ket qua nhap kho thanh cong de gui sang man hinh success.
class ThuMuaSuccessResult {
  const ThuMuaSuccessResult({
    required this.receiptCode,
    required this.quantity,
    required this.productName,
    required this.sku,
    required this.warehouseName,
    required this.performedBy,
    required this.completedAt,
    required this.orderId,
    required this.status,
    required this.unitCostPrice,
    this.expectedDate,
    this.actualWeightKg = 0,
    this.moisturePercent,
    this.debtAmount = 0,
  });

  final String receiptCode;
  final int quantity;
  final String productName;
  final String sku;
  final String warehouseName;
  final String performedBy;
  final DateTime completedAt;
  final int orderId;
  final String status;
  final double unitCostPrice;
  final DateTime? expectedDate;
  final double actualWeightKg;
  final double? moisturePercent;
  final double debtAmount;

  ThuMuaSuccessResult copyWithStatus(String value) {
    return ThuMuaSuccessResult(
      receiptCode: receiptCode,
      quantity: quantity,
      productName: productName,
      sku: sku,
      warehouseName: warehouseName,
      performedBy: performedBy,
      completedAt: completedAt,
      orderId: orderId,
      status: value,
      unitCostPrice: unitCostPrice,
      expectedDate: expectedDate,
      actualWeightKg: actualWeightKg,
      moisturePercent: moisturePercent,
      debtAmount: debtAmount,
    );
  }
}
