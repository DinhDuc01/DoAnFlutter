import '../../../core/api/json_reader.dart';

/// Id trạng thái đơn bán — khớp `SalesOrderStatusSeed` phía backend và hằng
/// `SALES_ORDER_STATUS` của web.
class SalesOrderStatusIds {
  const SalesOrderStatusIds._();

  static const int newOrder = 1;
  static const int pendingConfirm = 2;
  static const int reserved = 3;
  static const int awaitingMilling = 4;
  static const int preparing = 5;
  static const int delivering = 6;
  static const int completed = 7;
  static const int cancelled = 8;
}

/// Nhãn tiếng Việt theo id trạng thái (fallback về tên backend trả về).
String salesOrderStatusLabel(int statusId, [String? fallback]) {
  return switch (statusId) {
    SalesOrderStatusIds.newOrder => 'Mới tạo',
    SalesOrderStatusIds.pendingConfirm => 'Chờ xác nhận',
    SalesOrderStatusIds.reserved => 'Đã giữ hàng',
    SalesOrderStatusIds.awaitingMilling => 'Chờ xay xát',
    SalesOrderStatusIds.preparing => 'Đang chuẩn bị',
    SalesOrderStatusIds.delivering => 'Đang giao',
    SalesOrderStatusIds.completed => 'Hoàn tất',
    SalesOrderStatusIds.cancelled => 'Đã hủy',
    _ => fallback?.isNotEmpty == true ? fallback! : 'Không rõ',
  };
}

/// Nhãn kênh bán: DIRECT (bán trực tiếp) / WHOLESALE (bán sỉ).
String salesChannelLabel(String channel) =>
    channel.toUpperCase() == 'WHOLESALE' ? 'Bán sỉ' : 'Bán trực tiếp';

/// Một dòng trong danh sách đơn bán (khớp `SalesOrderListDto`).
class SalesOrderSummary {
  const SalesOrderSummary({
    required this.id,
    required this.soCode,
    required this.customerId,
    required this.customerName,
    required this.statusId,
    required this.statusName,
    required this.statusCode,
    required this.channel,
    required this.orderDate,
    required this.requiresMilling,
    required this.totalAmount,
    this.warehouseId,
    this.warehouseName,
    this.expectedDeliveryDate,
    this.riceVarietyDisplayName,
    this.riceVarietyCount = 0,
    this.hasUnconfiguredRiceVariety = false,
    this.totalRiceRequiredKg = 0,
    this.allocatedMillingRiceKg = 0,
    this.remainingMillingRiceKg = 0,
    this.depositAmount,
    this.note,
    this.cancelReason,
    this.createdDate,
  });

  final int id;
  final String soCode;
  final int customerId;
  final String customerName;
  final int statusId;
  final String statusName;
  final String statusCode;
  final String channel;
  final int? warehouseId;
  final String? warehouseName;
  final DateTime? orderDate;
  final DateTime? expectedDeliveryDate;
  final bool requiresMilling;
  final String? riceVarietyDisplayName;
  final int riceVarietyCount;
  final bool hasUnconfiguredRiceVariety;

  /// Tổng gạo đơn cần (kg) — dùng cho đơn phải xay.
  final double totalRiceRequiredKg;

  /// Gạo đã được các lệnh xay phân bổ cho đơn này (kg).
  final double allocatedMillingRiceKg;

  /// Gạo còn thiếu, cần tạo thêm lệnh xay (kg).
  final double remainingMillingRiceKg;

  final double totalAmount;
  final double? depositAmount;
  final String? note;
  final String? cancelReason;
  final DateTime? createdDate;

  String get statusLabel => salesOrderStatusLabel(statusId, statusName);

  /// Đơn cần xay và vẫn còn thiếu gạo → nên chuyển sang màn xay xát.
  bool get needsMilling =>
      requiresMilling &&
      statusId != SalesOrderStatusIds.cancelled &&
      statusId != SalesOrderStatusIds.completed;

  factory SalesOrderSummary.fromJson(Map<String, dynamic> json) =>
      SalesOrderSummary(
        id: JsonReader.integer(json, 'id') ?? 0,
        soCode: JsonReader.string(json, 'soCode') ?? '',
        customerId: JsonReader.integer(json, 'customerId') ?? 0,
        customerName: JsonReader.string(json, 'customerName') ?? 'Khách hàng',
        statusId: JsonReader.integer(json, 'statusId') ?? 0,
        statusName: JsonReader.string(json, 'statusName') ?? '',
        statusCode: JsonReader.string(json, 'statusCode') ?? '',
        channel: JsonReader.string(json, 'channel') ?? 'DIRECT',
        warehouseId: JsonReader.integer(json, 'warehouseId'),
        warehouseName: JsonReader.string(json, 'warehouseName'),
        orderDate: parseApiDate(json, 'orderDate'),
        expectedDeliveryDate: parseApiDate(json, 'expectedDeliveryDate'),
        requiresMilling: JsonReader.boolean(json, 'requiresMilling') ?? false,
        riceVarietyDisplayName:
            JsonReader.string(json, 'riceVarietyDisplayName') ??
                JsonReader.string(json, 'riceVarietyName'),
        riceVarietyCount: JsonReader.integer(json, 'riceVarietyCount') ?? 0,
        hasUnconfiguredRiceVariety:
            JsonReader.boolean(json, 'hasUnconfiguredRiceVariety') ?? false,
        totalRiceRequiredKg: JsonReader.decimal(json, 'totalRiceRequiredKg') ?? 0,
        allocatedMillingRiceKg:
            JsonReader.decimal(json, 'allocatedMillingRiceKg') ?? 0,
        remainingMillingRiceKg:
            JsonReader.decimal(json, 'remainingMillingRiceKg') ?? 0,
        totalAmount: JsonReader.decimal(json, 'totalAmount') ?? 0,
        depositAmount: JsonReader.decimal(json, 'depositAmount'),
        note: JsonReader.string(json, 'note'),
        cancelReason: JsonReader.string(json, 'cancelReason'),
        createdDate: parseApiDate(json, 'createdDate'),
      );
}

/// Chi tiết đơn bán (khớp `SalesOrderDetailDto`).
class SalesOrderDetail {
  const SalesOrderDetail({
    required this.id,
    required this.soCode,
    required this.customerId,
    required this.customerName,
    required this.statusId,
    required this.statusName,
    required this.statusCode,
    required this.channel,
    required this.requiresMilling,
    required this.totalAmount,
    required this.remainingAmount,
    required this.items,
    required this.outboundOrders,
    this.customerPhone,
    this.warehouseId,
    this.warehouseName,
    this.orderDate,
    this.expectedDeliveryDate,
    this.depositAmount,
    this.shippingAddress,
    this.note,
    this.cancelReason,
    this.createdDate,
  });

  final int id;
  final String soCode;
  final int customerId;
  final String customerName;
  final String? customerPhone;
  final int statusId;
  final String statusName;
  final String statusCode;
  final String channel;
  final int? warehouseId;
  final String? warehouseName;
  final DateTime? orderDate;
  final DateTime? expectedDeliveryDate;
  final bool requiresMilling;
  final double totalAmount;
  final double? depositAmount;
  final double remainingAmount;
  final String? shippingAddress;
  final String? note;
  final String? cancelReason;
  final DateTime? createdDate;
  final List<SalesOrderItem> items;
  final List<SalesOrderOutboundSummary> outboundOrders;

  String get statusLabel => salesOrderStatusLabel(statusId, statusName);

  /// Chỉ được hủy khi đơn chưa xuất kho — khớp `allowedStates` của backend.
  bool get canCancel => const [
        SalesOrderStatusIds.newOrder,
        SalesOrderStatusIds.pendingConfirm,
        SalesOrderStatusIds.reserved,
        SalesOrderStatusIds.preparing,
      ].contains(statusId);

  /// Chỉ tạo được phiếu xuất từ RESERVED/PREPARING (khớp backend).
  bool get canCreateOutbound => const [
        SalesOrderStatusIds.reserved,
        SalesOrderStatusIds.preparing,
      ].contains(statusId);

  /// Đơn cần xay xát và chưa kết thúc → hiện lối tắt sang màn xay xát.
  bool get needsMilling =>
      requiresMilling &&
      statusId != SalesOrderStatusIds.cancelled &&
      statusId != SalesOrderStatusIds.completed;

  /// Phiếu xuất đang ở trạng thái Nháp (nếu có) để đi tiếp luồng xuất kho.
  SalesOrderOutboundSummary? get draftOutbound {
    for (final outbound in outboundOrders) {
      if (outbound.statusCode.toUpperCase() == 'DRAFT') return outbound;
    }
    return null;
  }

  /// Phiếu xuất còn đang xử lý (chưa hủy, chưa hoàn tất).
  List<SalesOrderOutboundSummary> get activeOutbounds => outboundOrders
      .where((o) => o.statusCode.toUpperCase() != 'CANCELLED')
      .toList();

  factory SalesOrderDetail.fromJson(Map<String, dynamic> json) =>
      SalesOrderDetail(
        id: JsonReader.integer(json, 'id') ?? 0,
        soCode: JsonReader.string(json, 'soCode') ?? '',
        customerId: JsonReader.integer(json, 'customerId') ?? 0,
        customerName: JsonReader.string(json, 'customerName') ?? 'Khách hàng',
        customerPhone: JsonReader.string(json, 'customerPhone'),
        statusId: JsonReader.integer(json, 'statusId') ?? 0,
        statusName: JsonReader.string(json, 'statusName') ?? '',
        statusCode: JsonReader.string(json, 'statusCode') ?? '',
        channel: JsonReader.string(json, 'channel') ?? 'DIRECT',
        warehouseId: JsonReader.integer(json, 'warehouseId'),
        warehouseName: JsonReader.string(json, 'warehouseName'),
        orderDate: parseApiDate(json, 'orderDate'),
        expectedDeliveryDate: parseApiDate(json, 'expectedDeliveryDate'),
        requiresMilling: JsonReader.boolean(json, 'requiresMilling') ?? false,
        totalAmount: JsonReader.decimal(json, 'totalAmount') ?? 0,
        depositAmount: JsonReader.decimal(json, 'depositAmount'),
        remainingAmount: JsonReader.decimal(json, 'remainingAmount') ?? 0,
        shippingAddress: JsonReader.string(json, 'shippingAddress'),
        note: JsonReader.string(json, 'note'),
        cancelReason: JsonReader.string(json, 'cancelReason'),
        createdDate: parseApiDate(json, 'createdDate'),
        items: [
          for (final row in JsonReader.list(json, 'items') ?? const [])
            if (row is Map<String, dynamic>) SalesOrderItem.fromJson(row),
        ],
        outboundOrders: [
          for (final row in JsonReader.list(json, 'outboundOrders') ?? const [])
            if (row is Map<String, dynamic>)
              SalesOrderOutboundSummary.fromJson(row),
        ],
      );
}

/// Dòng sản phẩm của đơn bán.
class SalesOrderItem {
  const SalesOrderItem({
    required this.id,
    required this.productVariantId,
    required this.productVariantName,
    required this.quantityOrdered,
    required this.unitSalePrice,
    required this.discountAmount,
    required this.lineAmount,
    this.sku,
    this.note,
  });

  final int id;
  final int productVariantId;
  final String productVariantName;
  final String? sku;
  final double quantityOrdered;
  final double unitSalePrice;
  final double discountAmount;
  final double lineAmount;
  final String? note;

  factory SalesOrderItem.fromJson(Map<String, dynamic> json) => SalesOrderItem(
        id: JsonReader.integer(json, 'id') ?? 0,
        productVariantId: JsonReader.integer(json, 'productVariantId') ?? 0,
        productVariantName:
            JsonReader.string(json, 'productVariantName') ?? 'Sản phẩm',
        sku: JsonReader.string(json, 'sku'),
        quantityOrdered: JsonReader.decimal(json, 'quantityOrdered') ?? 0,
        unitSalePrice: JsonReader.decimal(json, 'unitSalePrice') ?? 0,
        discountAmount: JsonReader.decimal(json, 'discountAmount') ?? 0,
        lineAmount: JsonReader.decimal(json, 'lineAmount') ?? 0,
        note: JsonReader.string(json, 'note'),
      );
}

/// Tóm tắt phiếu xuất gắn với đơn bán.
class SalesOrderOutboundSummary {
  const SalesOrderOutboundSummary({
    required this.id,
    required this.statusId,
    required this.statusName,
    required this.statusCode,
    required this.totalDispatchedValue,
    required this.totalDispatchedSaleValue,
    this.completedDate,
  });

  final int id;
  final int statusId;
  final String statusName;
  final String statusCode;
  final double totalDispatchedValue;
  final double totalDispatchedSaleValue;
  final DateTime? completedDate;

  factory SalesOrderOutboundSummary.fromJson(Map<String, dynamic> json) =>
      SalesOrderOutboundSummary(
        id: JsonReader.integer(json, 'id') ?? 0,
        statusId: JsonReader.integer(json, 'outboundStatusId') ?? 0,
        statusName: JsonReader.string(json, 'outboundStatusName') ?? '',
        statusCode: JsonReader.string(json, 'outboundStatusCode') ?? '',
        totalDispatchedValue:
            JsonReader.decimal(json, 'totalDispatchedValue') ?? 0,
        totalDispatchedSaleValue:
            JsonReader.decimal(json, 'totalDispatchedSaleValue') ?? 0,
        completedDate: parseApiDate(json, 'completedDate'),
      );
}

/// Một trang kết quả của `/sales-orders/paged`.
class SalesOrderPage {
  const SalesOrderPage({required this.total, required this.items});

  /// Tổng số bản ghi KHỚP BỘ LỌC hiện tại (backend đã lọc), dùng để tính số trang.
  final int total;
  final List<SalesOrderSummary> items;
}

/// Đọc ngày từ JSON (backend trả chuỗi ISO), trả null nếu không hợp lệ.
DateTime? parseApiDate(Map<String, dynamic> json, String key) {
  final raw = JsonReader.string(json, key);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
