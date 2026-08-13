import '../../../core/api/json_reader.dart';
import '../../sales_orders/models/sales_order.dart' show parseApiDate;

/// Id trạng thái phiếu xuất — khớp `OutboundOrderStatusSeed` phía backend và
/// hằng `OUTBOUND_STATUS` của web.
class OutboundStatusIds {
  const OutboundStatusIds._();

  static const int draft = 1;
  static const int picking = 2;
  static const int packed = 3;
  static const int dispatched = 4;
  static const int completed = 5;
  static const int cancelled = 6;
  static const int deliveryFailed = 7;
}

/// Nhãn tiếng Việt theo id trạng thái phiếu xuất.
String outboundStatusLabel(int statusId, [String? fallback]) {
  return switch (statusId) {
    OutboundStatusIds.draft => 'Nháp',
    OutboundStatusIds.picking => 'Đang lấy hàng',
    OutboundStatusIds.packed => 'Chờ xuất kho',
    OutboundStatusIds.dispatched => 'Đang giao',
    OutboundStatusIds.completed => 'Hoàn tất',
    OutboundStatusIds.cancelled => 'Đã hủy',
    OutboundStatusIds.deliveryFailed => 'Giao thất bại',
    _ => fallback?.isNotEmpty == true ? fallback! : 'Không rõ',
  };
}

/// Một dòng danh sách phiếu xuất (khớp `OutboundOrderListDto`).
class OutboundOrderSummary {
  const OutboundOrderSummary({
    required this.id,
    required this.salesOrderId,
    required this.soCode,
    required this.customerName,
    required this.statusId,
    required this.statusName,
    required this.statusCode,
    required this.totalDispatchedValue,
    required this.totalDispatchedSaleValue,
    this.warehouseId,
    this.warehouseName,
    this.completedDate,
    this.note,
    this.cancelReason,
    this.createdDate,
  });

  final int id;
  final int salesOrderId;
  final String soCode;
  final String customerName;
  final int statusId;
  final String statusName;
  final String statusCode;
  final int? warehouseId;
  final String? warehouseName;
  final double totalDispatchedValue;
  final double totalDispatchedSaleValue;
  final DateTime? completedDate;
  final String? note;
  final String? cancelReason;
  final DateTime? createdDate;

  String get statusLabel => outboundStatusLabel(statusId, statusName);

  factory OutboundOrderSummary.fromJson(Map<String, dynamic> json) =>
      OutboundOrderSummary(
        id: JsonReader.integer(json, 'id') ?? 0,
        salesOrderId: JsonReader.integer(json, 'salesOrderId') ?? 0,
        soCode: JsonReader.string(json, 'soCode') ?? '',
        customerName: JsonReader.string(json, 'customerName') ?? 'Khách hàng',
        statusId: JsonReader.integer(json, 'outboundStatusId') ?? 0,
        statusName: JsonReader.string(json, 'outboundStatusName') ?? '',
        statusCode: JsonReader.string(json, 'outboundStatusCode') ?? '',
        warehouseId: JsonReader.integer(json, 'warehouseId'),
        warehouseName: JsonReader.string(json, 'warehouseName'),
        totalDispatchedValue:
            JsonReader.decimal(json, 'totalDispatchedValue') ?? 0,
        totalDispatchedSaleValue:
            JsonReader.decimal(json, 'totalDispatchedSaleValue') ?? 0,
        completedDate: parseApiDate(json, 'completedDate'),
        note: JsonReader.string(json, 'note'),
        cancelReason: JsonReader.string(json, 'cancelReason'),
        createdDate: parseApiDate(json, 'createdDate'),
      );
}

/// Chi tiết phiếu xuất (khớp `OutboundOrderDetailDto`).
class OutboundOrderDetail {
  const OutboundOrderDetail({
    required this.id,
    required this.salesOrderId,
    required this.soCode,
    required this.customerId,
    required this.customerName,
    required this.statusId,
    required this.statusName,
    required this.statusCode,
    required this.warehouseId,
    required this.warehouseName,
    required this.totalDispatchedValue,
    required this.totalDispatchedSaleValue,
    required this.items,
    this.completedDate,
    this.note,
    this.cancelReason,
    this.createdDate,
  });

  final int id;
  final int salesOrderId;
  final String soCode;
  final int customerId;
  final String customerName;
  final int statusId;
  final String statusName;
  final String statusCode;
  final int warehouseId;
  final String warehouseName;
  final double totalDispatchedValue;
  final double totalDispatchedSaleValue;
  final DateTime? completedDate;
  final String? note;
  final String? cancelReason;
  final DateTime? createdDate;
  final List<OutboundOrderItem> items;

  String get statusLabel => outboundStatusLabel(statusId, statusName);

  /// Lý do hủy đã nhập (chỉ hiển thị khi phiếu đã hủy).
  String? get cancelReasonText {
    if (statusId != OutboundStatusIds.cancelled) return null;
    final text = cancelReason?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// Tổng khối lượng theo kế hoạch (kg).
  double get plannedKg =>
      items.fold<double>(0, (sum, item) => sum + item.quantityOrdered);

  /// Tổng khối lượng thực lấy (kg).
  double get pickedKg =>
      items.fold<double>(0, (sum, item) => sum + item.quantityPicked);

  double get weightDiffKg => pickedKg - plannedKg;

  // ── Guard theo trạng thái, khớp đúng web ────────────────────────────
  bool get canAllocate => statusId == OutboundStatusIds.draft;
  bool get canPick => statusId == OutboundStatusIds.picking;
  bool get canPack => statusId == OutboundStatusIds.picking;
  bool get canDispatch => statusId == OutboundStatusIds.packed;
  bool get canDeliver => statusId == OutboundStatusIds.dispatched;
  bool get canCancel => const [
        OutboundStatusIds.draft,
        OutboundStatusIds.picking,
        OutboundStatusIds.packed,
      ].contains(statusId);

  /// Bước đang active trên thanh tiến trình (0-based, -1 = nhánh kết thúc lỗi).
  int get activeStep => switch (statusId) {
        OutboundStatusIds.draft => 0,
        OutboundStatusIds.picking => 1,
        OutboundStatusIds.packed => 2,
        OutboundStatusIds.dispatched => 3,
        OutboundStatusIds.completed => 4,
        _ => -1,
      };

  factory OutboundOrderDetail.fromJson(Map<String, dynamic> json) =>
      OutboundOrderDetail(
        id: JsonReader.integer(json, 'id') ?? 0,
        salesOrderId: JsonReader.integer(json, 'salesOrderId') ?? 0,
        soCode: JsonReader.string(json, 'soCode') ?? '',
        customerId: JsonReader.integer(json, 'customerId') ?? 0,
        customerName: JsonReader.string(json, 'customerName') ?? 'Khách hàng',
        statusId: JsonReader.integer(json, 'outboundStatusId') ?? 0,
        statusName: JsonReader.string(json, 'outboundStatusName') ?? '',
        statusCode: JsonReader.string(json, 'outboundStatusCode') ?? '',
        warehouseId: JsonReader.integer(json, 'warehouseId') ?? 0,
        warehouseName: JsonReader.string(json, 'warehouseName') ?? '',
        totalDispatchedValue:
            JsonReader.decimal(json, 'totalDispatchedValue') ?? 0,
        totalDispatchedSaleValue:
            JsonReader.decimal(json, 'totalDispatchedSaleValue') ?? 0,
        completedDate: parseApiDate(json, 'completedDate'),
        note: JsonReader.string(json, 'note'),
        cancelReason: JsonReader.string(json, 'cancelReason'),
        createdDate: parseApiDate(json, 'createdDate'),
        items: [
          for (final row in JsonReader.list(json, 'items') ?? const [])
            if (row is Map<String, dynamic>) OutboundOrderItem.fromJson(row),
        ],
      );
}

/// Dòng sản phẩm của phiếu xuất.
class OutboundOrderItem {
  const OutboundOrderItem({
    required this.id,
    required this.productVariantId,
    required this.productVariantName,
    required this.quantityOrdered,
    required this.quantityPicked,
    required this.unitCostPrice,
    required this.allocations,
    required this.allocationGroups,
    this.sku,
    this.salesOrderItemId,
    this.note,
  });

  final int id;
  final int productVariantId;
  final String productVariantName;
  final String? sku;
  final double quantityOrdered;
  final double quantityPicked;
  final double unitCostPrice;
  final int? salesOrderItemId;
  final String? note;
  final List<OutboundAllocation> allocations;
  final List<OutboundAllocationGroup> allocationGroups;

  double get allocatedKg =>
      allocations.fold<double>(0, (sum, a) => sum + a.quantityAllocated);

  /// Nhóm bao để hiển thị gọn. Nếu backend chưa trả `allocationGroups` thì tự
  /// gom theo lô/vị trí/khối lượng — giữ tương thích như web.
  List<OutboundAllocationGroup> get groups {
    if (allocationGroups.isNotEmpty) return allocationGroups;

    final sorted = [...allocations]..sort((a, b) => a.id.compareTo(b.id));
    final map = <String, OutboundAllocationGroup>{};
    for (final allocation in sorted) {
      final unitWeight = allocation.quantityAllocated;
      final key =
          '${allocation.inventoryId}:${allocation.locationId}:${unitWeight.toStringAsFixed(3)}';
      final current = map[key];
      if (current == null) {
        map[key] = OutboundAllocationGroup(
          groupKey: key,
          allocationIds: [allocation.id],
          inventoryId: allocation.inventoryId,
          paddyLotId: allocation.paddyLotId,
          paddyLotCode: allocation.paddyLotCode,
          locationId: allocation.locationId,
          locationCode: allocation.locationCode,
          bagCount: 1,
          weightPerBagKg: unitWeight,
          totalAllocatedKg: unitWeight,
          totalPickedKg: allocation.quantityPicked,
        );
      } else {
        map[key] = current.copyWithAdded(allocation);
      }
    }
    return map.values.toList();
  }

  factory OutboundOrderItem.fromJson(Map<String, dynamic> json) =>
      OutboundOrderItem(
        id: JsonReader.integer(json, 'id') ?? 0,
        productVariantId: JsonReader.integer(json, 'productVariantId') ?? 0,
        productVariantName:
            JsonReader.string(json, 'productVariantName') ?? 'Sản phẩm',
        sku: JsonReader.string(json, 'sku'),
        quantityOrdered: JsonReader.decimal(json, 'quantityOrdered') ?? 0,
        quantityPicked: JsonReader.decimal(json, 'quantityPicked') ?? 0,
        unitCostPrice: JsonReader.decimal(json, 'unitCostPrice') ?? 0,
        salesOrderItemId: JsonReader.integer(json, 'salesOrderItemId'),
        note: JsonReader.string(json, 'note'),
        allocations: [
          for (final row in JsonReader.list(json, 'allocations') ?? const [])
            if (row is Map<String, dynamic>) OutboundAllocation.fromJson(row),
        ],
        allocationGroups: [
          for (final row
              in JsonReader.list(json, 'allocationGroups') ?? const [])
            if (row is Map<String, dynamic>)
              OutboundAllocationGroup.fromJson(row),
        ],
      );
}

/// Một allocation (một bao) đã gắn lô/vị trí cho dòng phiếu xuất.
class OutboundAllocation {
  const OutboundAllocation({
    required this.id,
    required this.inventoryId,
    required this.locationId,
    required this.quantityAllocated,
    required this.quantityPicked,
    required this.unitCostPrice,
    this.paddyLotId,
    this.paddyLotCode,
    this.locationCode,
  });

  final int id;
  final int inventoryId;
  final int? paddyLotId;
  final String? paddyLotCode;
  final int locationId;
  final String? locationCode;
  final double quantityAllocated;
  final double quantityPicked;
  final double unitCostPrice;

  factory OutboundAllocation.fromJson(Map<String, dynamic> json) =>
      OutboundAllocation(
        id: JsonReader.integer(json, 'id') ?? 0,
        inventoryId: JsonReader.integer(json, 'inventoryId') ?? 0,
        paddyLotId: JsonReader.integer(json, 'paddyLotId'),
        paddyLotCode: JsonReader.string(json, 'paddyLotCode'),
        locationId: JsonReader.integer(json, 'locationId') ?? 0,
        locationCode: JsonReader.string(json, 'locationCode'),
        quantityAllocated: JsonReader.decimal(json, 'quantityAllocated') ?? 0,
        quantityPicked: JsonReader.decimal(json, 'quantityPicked') ?? 0,
        unitCostPrice: JsonReader.decimal(json, 'unitCostPrice') ?? 0,
      );
}

/// Nhóm các bao cùng lô/vị trí/khối lượng để UI không phải hiện hàng trăm dòng.
class OutboundAllocationGroup {
  const OutboundAllocationGroup({
    required this.groupKey,
    required this.allocationIds,
    required this.inventoryId,
    required this.locationId,
    required this.bagCount,
    required this.weightPerBagKg,
    required this.totalAllocatedKg,
    required this.totalPickedKg,
    this.paddyLotId,
    this.paddyLotCode,
    this.locationCode,
  });

  final String groupKey;
  final List<int> allocationIds;
  final int inventoryId;
  final int? paddyLotId;
  final String? paddyLotCode;
  final int locationId;
  final String? locationCode;
  final int bagCount;
  final double weightPerBagKg;
  final double totalAllocatedKg;
  final double totalPickedKg;

  String get lotLabel => paddyLotCode ?? 'INV-$inventoryId';
  String get locationLabel => locationCode ?? '—';

  OutboundAllocationGroup copyWithAdded(OutboundAllocation allocation) =>
      OutboundAllocationGroup(
        groupKey: groupKey,
        allocationIds: [...allocationIds, allocation.id],
        inventoryId: inventoryId,
        paddyLotId: paddyLotId,
        paddyLotCode: paddyLotCode,
        locationId: locationId,
        locationCode: locationCode,
        bagCount: bagCount + 1,
        weightPerBagKg: weightPerBagKg,
        totalAllocatedKg: totalAllocatedKg + allocation.quantityAllocated,
        totalPickedKg: totalPickedKg + allocation.quantityPicked,
      );

  factory OutboundAllocationGroup.fromJson(Map<String, dynamic> json) =>
      OutboundAllocationGroup(
        groupKey: JsonReader.string(json, 'groupKey') ?? '',
        allocationIds: [
          for (final id in JsonReader.list(json, 'allocationIds') ?? const [])
            if (id is num) id.toInt(),
        ],
        inventoryId: JsonReader.integer(json, 'inventoryId') ?? 0,
        paddyLotId: JsonReader.integer(json, 'paddyLotId'),
        paddyLotCode: JsonReader.string(json, 'paddyLotCode'),
        locationId: JsonReader.integer(json, 'locationId') ?? 0,
        locationCode: JsonReader.string(json, 'locationCode'),
        bagCount: JsonReader.integer(json, 'bagCount') ?? 0,
        weightPerBagKg: JsonReader.decimal(json, 'weightPerBagKg') ?? 0,
        totalAllocatedKg: JsonReader.decimal(json, 'totalAllocatedKg') ?? 0,
        totalPickedKg: JsonReader.decimal(json, 'totalPickedKg') ?? 0,
      );
}

/// Nguồn tồn có thể phân bổ cho phiếu xuất (`OutboundAllocationCandidateDto`).
class OutboundAllocationCandidate {
  const OutboundAllocationCandidate({
    required this.inventoryId,
    required this.productVariantId,
    required this.quantityOnHand,
    required this.selectableQuantity,
    this.paddyLotId,
    this.lotCode,
    this.locationId,
    this.locationCode,
    this.reservedByOtherOrders = 0,
    this.reservedForThisSalesOrder = 0,
  });

  final int inventoryId;
  final int productVariantId;
  final int? paddyLotId;
  final String? lotCode;
  final int? locationId;
  final String? locationCode;
  final double quantityOnHand;
  final double reservedByOtherOrders;
  final double reservedForThisSalesOrder;

  /// Khối lượng thực sự chọn được cho phiếu này.
  final double selectableQuantity;

  String get lotLabel => lotCode ?? 'INV-$inventoryId';
  String get locationLabel => locationCode ?? '—';

  factory OutboundAllocationCandidate.fromJson(Map<String, dynamic> json) =>
      OutboundAllocationCandidate(
        inventoryId: JsonReader.integer(json, 'inventoryId') ?? 0,
        productVariantId: JsonReader.integer(json, 'productVariantId') ?? 0,
        paddyLotId: JsonReader.integer(json, 'paddyLotId'),
        lotCode: JsonReader.string(json, 'lotCode'),
        locationId: JsonReader.integer(json, 'locationId'),
        locationCode: JsonReader.string(json, 'locationCode'),
        quantityOnHand: JsonReader.decimal(json, 'quantityOnHand') ?? 0,
        reservedByOtherOrders:
            JsonReader.decimal(json, 'reservedByOtherOrders') ?? 0,
        reservedForThisSalesOrder:
            JsonReader.decimal(json, 'reservedForThisSalesOrder') ?? 0,
        selectableQuantity: JsonReader.decimal(json, 'selectableQuantity') ?? 0,
      );
}

/// Một trang kết quả của `/outbound-orders/paged`.
class OutboundOrderPage {
  const OutboundOrderPage({required this.total, required this.items});

  /// Tổng số bản ghi KHỚP BỘ LỌC hiện tại (backend đã lọc), dùng để tính số trang.
  final int total;
  final List<OutboundOrderSummary> items;
}

/// Kết quả trả về của `complete-delivery`.
class CompleteDeliveryResult {
  const CompleteDeliveryResult({required this.paymentAmount, this.remainingDebt});

  final double paymentAmount;

  /// Dư nợ còn lại sau khi thu tiền; null nghĩa là backend không xác định.
  final double? remainingDebt;

  factory CompleteDeliveryResult.fromJson(Map<String, dynamic> json) =>
      CompleteDeliveryResult(
        paymentAmount: JsonReader.decimal(json, 'paymentAmount') ?? 0,
        remainingDebt: JsonReader.decimal(json, 'remainingDebt'),
      );
}

/// Số dư công nợ phải thu của một phiếu xuất (lấy từ API công nợ).
class OutboundDebtSnapshot {
  const OutboundDebtSnapshot({
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
  });

  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
}
