import '../../../core/api/json_reader.dart';

/// Model màn "Nhập kho & xếp vị trí" (Store-in / Put-away) — khớp DTO backend
/// và bản web `inbound-putaway`.

/// Trạng thái phiếu nhập đã chuẩn hoá về chữ thường để so sánh.
class InboundOrderStatuses {
  const InboundOrderStatuses._();

  static const draft = 'draft';
  static const submitted = 'submitted';
  static const approved = 'approved';
  static const receiving = 'receiving';
  static const partiallyReceived = 'partially_received';
  static const confirmed = 'confirmed';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
}

class InboundOrder {
  const InboundOrder({
    required this.id,
    required this.poCode,
    required this.warehouseId,
    this.warehouseName,
    this.supplierName,
    this.statusName,
    this.statusCode,
    this.sourceType,
    this.paddyPurchaseReceiptId,
    this.paddyPurchaseReceiptCode,
    this.note,
    this.items = const <InboundOrderItem>[],
  });

  final int id;
  final String poCode;
  final int warehouseId;
  final String? warehouseName;
  final String? supplierName;
  final String? statusName;
  final String? statusCode;
  final String? sourceType;
  final int? paddyPurchaseReceiptId;
  final String? paddyPurchaseReceiptCode;
  final String? note;
  final List<InboundOrderItem> items;

  String get normalizedStatus => (statusCode ?? '').trim().toLowerCase();

  factory InboundOrder.fromJson(Map<String, dynamic> json) => InboundOrder(
        id: JsonReader.integer(json, 'id') ?? 0,
        poCode: JsonReader.string(json, 'poCode') ?? '',
        warehouseId: JsonReader.integer(json, 'warehouseId') ?? 0,
        warehouseName: JsonReader.string(json, 'warehouseName'),
        supplierName: JsonReader.string(json, 'supplierName'),
        statusName: JsonReader.string(json, 'inboundOrderStatusName'),
        statusCode: JsonReader.string(json, 'inboundOrderStatusCode'),
        sourceType: JsonReader.string(json, 'sourceType'),
        paddyPurchaseReceiptId: JsonReader.integer(json, 'paddyPurchaseReceiptId'),
        paddyPurchaseReceiptCode:
            JsonReader.string(json, 'paddyPurchaseReceiptCode'),
        note: JsonReader.string(json, 'note'),
        items: [
          for (final item in JsonReader.list(json, 'items') ?? const <dynamic>[])
            if (item is Map<String, dynamic>) InboundOrderItem.fromJson(item),
        ],
      );
}

class InboundOrderItem {
  const InboundOrderItem({
    required this.id,
    required this.inboundOrderId,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.receiptStatus,
    this.paddyLotId,
    this.paddyLotCode,
    this.paddyQualityStatus,
    this.productVariantName,
    this.sku,
    this.quantityEntered,
    this.confirmedLocationId,
    this.confirmedLocationCode,
  });

  final int id;
  final int inboundOrderId;
  final double quantityOrdered;
  final double quantityReceived;
  final String receiptStatus;
  final int? paddyLotId;
  final String? paddyLotCode;
  final String? paddyQualityStatus;
  final String? productVariantName;
  final String? sku;
  final double? quantityEntered;
  final int? confirmedLocationId;
  final String? confirmedLocationCode;

  double get remainingKg {
    final value = quantityOrdered - quantityReceived;
    return value <= 0 ? 0 : value;
  }

  /// Lô không đạt kiểm định thì chỉ được xếp vào khu cách ly.
  bool get needsQuarantine =>
      (paddyQualityStatus ?? '').trim().toUpperCase() == 'FAILED';

  /// Đã ghi nhận khối lượng — bước sau chỉ cần chọn vị trí và xác nhận.
  bool get quantityCaptured => const [
        'QuantityEntered',
        'WeightVerified',
        'PutawaySelected',
      ].contains(receiptStatus);

  factory InboundOrderItem.fromJson(Map<String, dynamic> json) =>
      InboundOrderItem(
        id: JsonReader.integer(json, 'id') ?? 0,
        inboundOrderId: JsonReader.integer(json, 'inboundOrderId') ?? 0,
        quantityOrdered: JsonReader.decimal(json, 'quantityOrdered') ?? 0,
        quantityReceived: JsonReader.decimal(json, 'quantityReceived') ?? 0,
        receiptStatus: JsonReader.string(json, 'receiptStatus') ?? '',
        paddyLotId: JsonReader.integer(json, 'paddyLotId'),
        paddyLotCode: JsonReader.string(json, 'paddyLotCode'),
        paddyQualityStatus: JsonReader.string(json, 'paddyQualityStatus'),
        productVariantName: JsonReader.string(json, 'productVariantName'),
        sku: JsonReader.string(json, 'sku'),
        quantityEntered: JsonReader.decimal(json, 'quantityEntered'),
        confirmedLocationId: JsonReader.integer(json, 'confirmedLocationId'),
        confirmedLocationCode: JsonReader.string(json, 'confirmedLocationCode'),
      );
}

/// Một dòng hàng chờ xếp kho = phiếu nhập + dòng hàng của phiếu đó.
class InboundPutawayLine {
  const InboundPutawayLine({required this.order, required this.item});

  final InboundOrder order;
  final InboundOrderItem item;

  String get title =>
      '${item.paddyLotCode ?? order.poCode} · '
      '${item.productVariantName ?? item.sku ?? 'Lúa nguyên liệu'}';

  String get sourceLabel =>
      '${order.paddyPurchaseReceiptCode ?? order.poCode} · '
      '${order.supplierName ?? 'Không rõ nông dân'}';
}

class PutawaySuggestion {
  const PutawaySuggestion({
    required this.locationId,
    required this.score,
    required this.availableCapacity,
    required this.currentOccupancy,
    required this.priority,
    required this.categoryMatch,
    required this.recommendedWeightKg,
    required this.canFitWhole,
    required this.isQuarantine,
    this.zoneName,
    this.shelfRow,
    this.shelfLevel,
    this.slotCode,
  });

  final int locationId;
  final double score;
  final double availableCapacity;
  final double currentOccupancy;
  final int priority;
  final bool categoryMatch;
  final double recommendedWeightKg;
  final bool canFitWhole;
  final bool isQuarantine;
  final String? zoneName;
  final String? shelfRow;
  final String? shelfLevel;
  final String? slotCode;

  String get label => locationLabelOf(
        zoneName: zoneName,
        shelfRow: shelfRow,
        shelfLevel: shelfLevel,
        slotCode: slotCode,
      );

  int get occupancyPercent {
    final max = currentOccupancy + availableCapacity;
    if (max <= 0) return 0;
    final percent = (currentOccupancy / max * 100).round();
    return percent < 0 ? 0 : (percent > 100 ? 100 : percent);
  }

  factory PutawaySuggestion.fromJson(Map<String, dynamic> json) =>
      PutawaySuggestion(
        locationId: JsonReader.integer(json, 'locationId') ?? 0,
        score: JsonReader.decimal(json, 'score') ?? 0,
        availableCapacity: JsonReader.decimal(json, 'availableCapacity') ?? 0,
        currentOccupancy: JsonReader.decimal(json, 'currentOccupancy') ?? 0,
        priority: JsonReader.integer(json, 'priority') ?? 0,
        categoryMatch: JsonReader.boolean(json, 'categoryMatch') ?? false,
        recommendedWeightKg: JsonReader.decimal(json, 'recommendedWeightKg') ?? 0,
        canFitWhole: JsonReader.boolean(json, 'canFitWhole') ?? false,
        isQuarantine: JsonReader.boolean(json, 'isQuarantine') ?? false,
        zoneName: JsonReader.string(json, 'zoneName'),
        shelfRow: JsonReader.string(json, 'shelfRow'),
        shelfLevel: JsonReader.string(json, 'shelfLevel'),
        slotCode: JsonReader.string(json, 'slotCode'),
      );
}

/// Vị trí lưu trữ (khớp `LocationDetailDto`).
class StorageLocation {
  const StorageLocation({
    required this.id,
    required this.warehouseId,
    required this.zoneName,
    required this.isActive,
    this.shelfRow,
    this.shelfLevel,
    this.slotCode,
    this.maxCapacity = 0,
    this.currentOccupancy = 0,
    this.priority = 0,
    this.isQuarantine = false,
    this.isOutboundStaging = false,
    this.isLockedForOutbound = false,
  });

  final int id;
  final int warehouseId;
  final String zoneName;
  final bool isActive;
  final String? shelfRow;
  final String? shelfLevel;
  final String? slotCode;
  final double maxCapacity;
  final double currentOccupancy;
  final int priority;
  final bool isQuarantine;
  final bool isOutboundStaging;
  final bool isLockedForOutbound;

  double get freeCapacityKg {
    final value = maxCapacity - currentOccupancy;
    return value <= 0 ? 0 : value;
  }

  String get label => locationLabelOf(
        zoneName: zoneName,
        shelfRow: shelfRow,
        shelfLevel: shelfLevel,
        slotCode: slotCode,
      );

  factory StorageLocation.fromJson(Map<String, dynamic> json) => StorageLocation(
        id: JsonReader.integer(json, 'id') ?? 0,
        warehouseId: JsonReader.integer(json, 'warehouseId') ?? 0,
        zoneName: JsonReader.string(json, 'zoneName') ?? '',
        isActive: JsonReader.boolean(json, 'isActive') ?? false,
        shelfRow: JsonReader.string(json, 'shelfRow'),
        shelfLevel: JsonReader.string(json, 'shelfLevel'),
        slotCode: JsonReader.string(json, 'slotCode'),
        maxCapacity: JsonReader.decimal(json, 'maxCapacity') ?? 0,
        currentOccupancy: JsonReader.decimal(json, 'currentOccupancy') ?? 0,
        priority: JsonReader.integer(json, 'priority') ?? 0,
        isQuarantine: JsonReader.boolean(json, 'isQuarantine') ?? false,
        isOutboundStaging: JsonReader.boolean(json, 'isOutboundStaging') ?? false,
        isLockedForOutbound:
            JsonReader.boolean(json, 'isLockedForOutbound') ?? false,
      );
}

class BagPutawayBag {
  const BagPutawayBag({
    required this.id,
    required this.bagNo,
    required this.weightKg,
  });

  final int id;
  final int bagNo;
  final double weightKg;

  factory BagPutawayBag.fromJson(Map<String, dynamic> json) => BagPutawayBag(
        id: JsonReader.integer(json, 'id') ?? 0,
        bagNo: JsonReader.integer(json, 'bagNo') ?? 0,
        weightKg: JsonReader.decimal(json, 'weightKg') ?? 0,
      );
}

/// Một cột chứa bao trong phương án xếp. Mảng [bags] giữ thứ tự vật lý
/// ĐÁY → ĐỈNH đúng như backend nhận (LIFO: nhập sau nằm trên đỉnh, lấy trước).
class BagPutawayColumn {
  const BagPutawayColumn({
    required this.locationId,
    required this.slotCode,
    required this.bags,
    required this.totalKg,
    required this.capacityRemainAfter,
    this.priorityRank,
    this.reason,
  });

  final int locationId;
  final String slotCode;
  final List<BagPutawayBag> bags;
  final double totalKg;
  final double capacityRemainAfter;
  final int? priorityRank;
  final String? reason;

  List<int> get bagIds => [for (final bag in bags) bag.id];

  BagPutawayColumn copyWith({
    List<BagPutawayBag>? bags,
    double? totalKg,
    double? capacityRemainAfter,
    int? priorityRank,
  }) =>
      BagPutawayColumn(
        locationId: locationId,
        slotCode: slotCode,
        bags: bags ?? this.bags,
        totalKg: totalKg ?? this.totalKg,
        capacityRemainAfter: capacityRemainAfter ?? this.capacityRemainAfter,
        priorityRank: priorityRank ?? this.priorityRank,
        reason: reason,
      );

  factory BagPutawayColumn.fromJson(Map<String, dynamic> json) =>
      BagPutawayColumn(
        locationId: JsonReader.integer(json, 'locationId') ?? 0,
        slotCode: JsonReader.string(json, 'slotCode') ?? '',
        bags: [
          for (final bag in JsonReader.list(json, 'bags') ?? const <dynamic>[])
            if (bag is Map<String, dynamic>) BagPutawayBag.fromJson(bag),
        ],
        totalKg: JsonReader.decimal(json, 'totalKg') ?? 0,
        capacityRemainAfter: JsonReader.decimal(json, 'capacityRemainAfter') ?? 0,
        priorityRank: JsonReader.integer(json, 'priorityRank'),
        reason: JsonReader.string(json, 'reason'),
      );
}

class BagPutawayCandidate {
  const BagPutawayCandidate({
    required this.locationId,
    required this.slotCode,
    required this.capacityAvailableKg,
    this.priority = 0,
    this.containsSameVariant = false,
    this.reason,
  });

  final int locationId;
  final String slotCode;
  final double capacityAvailableKg;
  final int priority;
  final bool containsSameVariant;
  final String? reason;

  factory BagPutawayCandidate.fromJson(Map<String, dynamic> json) =>
      BagPutawayCandidate(
        locationId: JsonReader.integer(json, 'locationId') ?? 0,
        slotCode: JsonReader.string(json, 'slotCode') ?? '',
        capacityAvailableKg:
            JsonReader.decimal(json, 'capacityAvailableKg') ?? 0,
        priority: JsonReader.integer(json, 'priority') ?? 0,
        containsSameVariant:
            JsonReader.boolean(json, 'containsSameVariant') ?? false,
        reason: JsonReader.string(json, 'reason'),
      );
}

class BagPutawayPlan {
  const BagPutawayPlan({
    required this.columns,
    required this.candidateLocations,
    required this.unplacedBagIds,
  });

  final List<BagPutawayColumn> columns;
  final List<BagPutawayCandidate> candidateLocations;
  final List<int> unplacedBagIds;

  int get bagCount =>
      columns.fold<int>(0, (sum, column) => sum + column.bags.length);

  double get totalKg =>
      columns.fold<double>(0, (sum, column) => sum + column.totalKg);

  BagPutawayPlan copyWith({List<BagPutawayColumn>? columns}) => BagPutawayPlan(
        columns: columns ?? this.columns,
        candidateLocations: candidateLocations,
        unplacedBagIds: unplacedBagIds,
      );

  /// Sức chứa còn lại của một vị trí: ưu tiên cột đang xếp, nếu chưa có cột thì
  /// lấy sức chứa khả dụng của vị trí ứng viên (giống `candidateCapacityRemain`).
  double capacityRemain(int locationId) {
    for (final column in columns) {
      if (column.locationId == locationId) return column.capacityRemainAfter;
    }
    for (final candidate in candidateLocations) {
      if (candidate.locationId == locationId) return candidate.capacityAvailableKg;
    }
    return 0;
  }

  factory BagPutawayPlan.fromJson(Map<String, dynamic> json) => BagPutawayPlan(
        columns: [
          for (final column
              in JsonReader.list(json, 'columns') ?? const <dynamic>[])
            if (column is Map<String, dynamic>) BagPutawayColumn.fromJson(column),
        ],
        candidateLocations: [
          for (final candidate
              in JsonReader.list(json, 'candidateLocations') ?? const <dynamic>[])
            if (candidate is Map<String, dynamic>)
              BagPutawayCandidate.fromJson(candidate),
        ],
        unplacedBagIds: [
          for (final id in JsonReader.list(json, 'unplacedBagIds') ?? const <dynamic>[])
            if (id is num) id.toInt(),
        ],
      );
}

class InboundOrderException implements Exception {
  const InboundOrderException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// "Khu A / Cột 2 / Lớp 1 / Ô A-02" — cùng cách ghép nhãn với web.
String locationLabelOf({
  String? zoneName,
  String? shelfRow,
  String? shelfLevel,
  String? slotCode,
}) {
  final parts = <String>[
    if ((zoneName ?? '').trim().isNotEmpty) 'Khu ${zoneName!.trim()}',
    if ((shelfRow ?? '').trim().isNotEmpty) 'Cột ${shelfRow!.trim()}',
    if ((shelfLevel ?? '').trim().isNotEmpty) 'Lớp ${shelfLevel!.trim()}',
    if ((slotCode ?? '').trim().isNotEmpty) 'Ô ${slotCode!.trim()}',
  ];
  return parts.isEmpty ? 'Vị trí chưa đặt tên' : parts.join(' / ');
}
