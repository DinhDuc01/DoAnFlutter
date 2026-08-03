class GiaoHangCustomer {
  const GiaoHangCustomer({
    required this.id,
    required this.code,
    required this.name,
    this.contactPerson,
    this.phone,
    this.address,
  });

  final int id;
  final String code;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? address;
}

enum SalesMode { delivery, direct }

extension SalesModeLabel on SalesMode {
  String get channel => this == SalesMode.delivery ? 'WHOLESALE' : 'DIRECT';
  String get label =>
      this == SalesMode.delivery ? 'Giao hàng' : 'Bán trực tiếp';
}

class GiaoHangReceipt {
  const GiaoHangReceipt({
    required this.productVariantId,
    required this.warehouseId,
    required this.warehouseName,
    required this.status,
    required this.productName,
    required this.sku,
    required this.currentStock,
    required this.receiptCode,
    required this.quantity,
    required this.noteHint,
    this.locationId,
    this.locationCode,
    this.customer,
    this.salesMode = SalesMode.delivery,
    this.expectedDeliveryDate,
    this.unitSalePrice = 0,
    this.shippingAddress,
  });

  final int productVariantId;
  final int warehouseId;
  final String warehouseName;
  final int? locationId;
  final String? locationCode;
  final String status;
  final String productName;
  final String sku;
  final int currentStock;
  final String receiptCode;
  final int quantity;
  final String noteHint;
  final GiaoHangCustomer? customer;
  final SalesMode salesMode;
  final DateTime? expectedDeliveryDate;
  final double unitSalePrice;
  final String? shippingAddress;

  String get customerName => customer?.name ?? 'Chưa chọn khách hàng';

  GiaoHangReceipt copyWith({
    GiaoHangCustomer? customer,
    SalesMode? salesMode,
    DateTime? expectedDeliveryDate,
    String? shippingAddress,
  }) {
    return GiaoHangReceipt(
      productVariantId: productVariantId,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      locationId: locationId,
      locationCode: locationCode,
      status: status,
      productName: productName,
      sku: sku,
      currentStock: currentStock,
      receiptCode: receiptCode,
      quantity: quantity,
      noteHint: noteHint,
      customer: customer ?? this.customer,
      salesMode: salesMode ?? this.salesMode,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      unitSalePrice: unitSalePrice,
      shippingAddress: shippingAddress ?? this.shippingAddress,
    );
  }
}

class SalesOrderSubmission {
  const SalesOrderSubmission({
    required this.id,
    required this.code,
    required this.status,
  });

  final int id;
  final String code;
  final String status;
}

class GiaoHangSuccessResult {
  const GiaoHangSuccessResult({
    required this.receiptCode,
    required this.quantity,
    required this.productName,
    required this.sku,
    required this.customerName,
    required this.performedBy,
    required this.completedAt,
    required this.warehouseName,
    required this.remainingStock,
    this.locationCode,
    this.customerPhone,
    this.customerAddress,
    this.note,
    required this.orderId,
    required this.status,
    required this.salesMode,
    required this.unitSalePrice,
    this.expectedDeliveryDate,
  });

  final String receiptCode;
  final int quantity;
  final String productName;
  final String sku;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String warehouseName;
  final String? locationCode;
  final int remainingStock;
  final String performedBy;
  final DateTime completedAt;
  final String? note;
  final int orderId;
  final String status;
  final SalesMode salesMode;
  final double unitSalePrice;
  final DateTime? expectedDeliveryDate;

  GiaoHangSuccessResult copyWithStatus(String value) {
    return GiaoHangSuccessResult(
      receiptCode: receiptCode,
      quantity: quantity,
      productName: productName,
      sku: sku,
      customerName: customerName,
      performedBy: performedBy,
      completedAt: completedAt,
      warehouseName: warehouseName,
      remainingStock: remainingStock,
      locationCode: locationCode,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      note: note,
      orderId: orderId,
      status: value,
      salesMode: salesMode,
      unitSalePrice: unitSalePrice,
      expectedDeliveryDate: expectedDeliveryDate,
    );
  }
}
