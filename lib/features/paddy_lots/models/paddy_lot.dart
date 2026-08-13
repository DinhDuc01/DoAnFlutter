import '../../../core/api/json_reader.dart';

class PaddyLotSummary {
  const PaddyLotSummary({
    required this.id,
    required this.lotCode,
    required this.lotType,
    required this.productVariantId,
    required this.warehouseId,
    required this.initialWeightKg,
    required this.remainingWeightKg,
    this.productName,
    this.sku,
    this.riceVarietyName,
    this.warehouseName,
    this.locationId,
    this.locationCode,
    this.statusId,
    this.statusName,
    this.qualityStatus,
    this.sourceReceiptId,
    this.sourceMillingOrderId,
    this.inboundDate,
    this.createdDate,
    this.bagCount,
    this.isQuarantined,
    this.isSellable,
  });

  final int id;
  final String lotCode;
  final String lotType;
  final int productVariantId;
  final String? productName;
  final String? sku;
  final String? riceVarietyName;
  final int warehouseId;
  final String? warehouseName;
  final int? locationId;
  final String? locationCode;
  final int? statusId;
  final String? statusName;
  final double initialWeightKg;
  final double remainingWeightKg;
  final String? qualityStatus;
  final int? sourceReceiptId;
  final int? sourceMillingOrderId;
  final DateTime? inboundDate;
  final DateTime? createdDate;
  final int? bagCount;
  final bool? isQuarantined;
  final bool? isSellable;

  bool get needsAttention {
    final quality = qualityStatus?.toUpperCase() ?? '';
    final status = statusName?.toUpperCase() ?? '';
    return isQuarantined == true ||
        isSellable == false ||
        quality.contains('FAIL') ||
        quality.contains('KHÔNG') ||
        status.contains('QUARANTINE') ||
        status.contains('CÁCH LY');
  }

  factory PaddyLotSummary.fromJson(Map<String, dynamic> json) {
    return PaddyLotSummary(
      id: JsonReader.integer(json, 'id') ?? 0,
      lotCode: JsonReader.string(json, 'lotCode') ?? '',
      lotType: JsonReader.string(json, 'lotType') ?? 'UNKNOWN',
      productVariantId: JsonReader.integer(json, 'productVariantId') ?? 0,
      productName: JsonReader.string(json, 'productVariantName'),
      sku: JsonReader.string(json, 'sku'),
      riceVarietyName: JsonReader.string(json, 'riceVarietyName'),
      warehouseId: JsonReader.integer(json, 'warehouseId') ?? 0,
      warehouseName: JsonReader.string(json, 'warehouseName'),
      locationId: JsonReader.integer(json, 'locationId'),
      locationCode: JsonReader.string(json, 'locationCode'),
      statusId: JsonReader.integer(json, 'statusId'),
      statusName: JsonReader.string(json, 'statusName'),
      initialWeightKg: JsonReader.decimal(json, 'initialWeightKg') ?? 0,
      remainingWeightKg: JsonReader.decimal(json, 'remainingWeightKg') ?? 0,
      qualityStatus: JsonReader.string(json, 'qualityStatus'),
      sourceReceiptId: JsonReader.integer(json, 'sourceReceiptId'),
      sourceMillingOrderId: JsonReader.integer(json, 'sourceMillingOrderId'),
      inboundDate: _date(json, 'inboundDate'),
      createdDate: _date(json, 'createdDate'),
      bagCount: JsonReader.integer(json, 'bagCount'),
      isQuarantined: JsonReader.boolean(json, 'isQuarantined'),
      isSellable: JsonReader.boolean(json, 'isSellable'),
    );
  }
}

class PaddyLotDetail extends PaddyLotSummary {
  const PaddyLotDetail({
    required super.id,
    required super.lotCode,
    required super.lotType,
    required super.productVariantId,
    required super.warehouseId,
    required super.initialWeightKg,
    required super.remainingWeightKg,
    super.productName,
    super.sku,
    super.riceVarietyName,
    super.warehouseName,
    super.locationId,
    super.locationCode,
    super.statusId,
    super.statusName,
    super.qualityStatus,
    super.sourceReceiptId,
    super.sourceMillingOrderId,
    super.inboundDate,
    super.createdDate,
    super.bagCount,
    super.isQuarantined,
    super.isSellable,
    this.lastModifiedDate,
  });

  final DateTime? lastModifiedDate;

  factory PaddyLotDetail.fromJson(Map<String, dynamic> json) {
    final summary = PaddyLotSummary.fromJson(json);
    return PaddyLotDetail(
      id: summary.id,
      lotCode: summary.lotCode,
      lotType: summary.lotType,
      productVariantId: summary.productVariantId,
      warehouseId: summary.warehouseId,
      initialWeightKg: summary.initialWeightKg,
      remainingWeightKg: summary.remainingWeightKg,
      productName: summary.productName,
      sku: summary.sku,
      riceVarietyName: summary.riceVarietyName,
      warehouseName: summary.warehouseName,
      locationId: summary.locationId,
      locationCode: summary.locationCode,
      statusId: summary.statusId,
      statusName: summary.statusName,
      qualityStatus: summary.qualityStatus,
      sourceReceiptId: summary.sourceReceiptId,
      sourceMillingOrderId: summary.sourceMillingOrderId,
      inboundDate: summary.inboundDate,
      createdDate: summary.createdDate,
      bagCount: summary.bagCount,
      isQuarantined: summary.isQuarantined,
      isSellable: summary.isSellable,
      lastModifiedDate: _date(json, 'lastModifiedDate'),
    );
  }
}

class TraceabilityEvent {
  const TraceabilityEvent({
    required this.eventAt,
    required this.eventType,
    required this.title,
    required this.description,
    required this.referenceType,
    required this.referenceId,
    required this.sequence,
    this.referenceCode,
    this.status,
    this.quantityKg,
    this.paddyLotIds = const [],
  });

  final DateTime eventAt;
  final String eventType;
  final String title;
  final String description;
  final String referenceType;
  final int referenceId;
  final String? referenceCode;
  final String? status;
  final double? quantityKg;
  final int sequence;
  final List<int> paddyLotIds;

  factory TraceabilityEvent.fromJson(Map<String, dynamic> json) {
    final ids = JsonReader.list(json, 'paddyLotIds') ?? const [];
    return TraceabilityEvent(
      eventAt: _date(json, 'eventAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
      eventType: JsonReader.string(json, 'eventType') ?? 'UNKNOWN',
      title: JsonReader.string(json, 'title') ?? 'Sự kiện truy vết',
      description: JsonReader.string(json, 'description') ?? '',
      referenceType: JsonReader.string(json, 'referenceType') ?? '',
      referenceId: JsonReader.integer(json, 'referenceId') ?? 0,
      referenceCode: JsonReader.string(json, 'referenceCode'),
      status: JsonReader.string(json, 'status'),
      quantityKg: JsonReader.decimal(json, 'quantityKg'),
      sequence: JsonReader.integer(json, 'sequence') ?? 0,
      paddyLotIds: [
        for (final id in ids)
          if (id is num) id.toInt()
      ],
    );
  }
}

/// Một lô nằm trong cây quan hệ của lô đang tra cứu (cha/con/chính nó).
class TraceabilityLot {
  const TraceabilityLot({
    required this.id,
    required this.lotCode,
    required this.lotType,
    required this.relationRole,
    required this.productVariantId,
    required this.initialWeightKg,
    required this.remainingWeightKg,
    required this.isSellable,
    required this.isQuarantined,
    required this.warehouseId,
    this.sku,
    this.productVariantName,
    this.riceVarietyName,
    this.statusName,
    this.statusCode,
    this.warehouseName,
    this.locationCode,
    this.qualityStatus,
    this.inboundDate,
  });

  final int id;
  final String lotCode;
  final String lotType;

  /// SELF | PARENT | CHILD ... — vai trò của lô này so với lô được tra cứu.
  final String relationRole;
  final int productVariantId;
  final String? sku;
  final String? productVariantName;
  final String? riceVarietyName;
  final String? statusName;
  final String? statusCode;
  final bool isSellable;
  final bool isQuarantined;
  final int warehouseId;
  final String? warehouseName;
  final String? locationCode;
  final double initialWeightKg;
  final double remainingWeightKg;
  final String? qualityStatus;
  final DateTime? inboundDate;

  bool get isSelf => relationRole.toUpperCase() == 'SELF';

  factory TraceabilityLot.fromJson(Map<String, dynamic> json) =>
      TraceabilityLot(
        id: JsonReader.integer(json, 'id') ?? 0,
        lotCode: JsonReader.string(json, 'lotCode') ?? '',
        lotType: JsonReader.string(json, 'lotType') ?? '',
        relationRole: JsonReader.string(json, 'relationRole') ?? '',
        productVariantId: JsonReader.integer(json, 'productVariantId') ?? 0,
        sku: JsonReader.string(json, 'sku'),
        productVariantName: JsonReader.string(json, 'productVariantName'),
        riceVarietyName: JsonReader.string(json, 'riceVarietyName'),
        statusName: JsonReader.string(json, 'statusName'),
        statusCode: JsonReader.string(json, 'statusCode'),
        isSellable: JsonReader.boolean(json, 'isSellable') ?? false,
        isQuarantined: JsonReader.boolean(json, 'isQuarantined') ?? false,
        warehouseId: JsonReader.integer(json, 'warehouseId') ?? 0,
        warehouseName: JsonReader.string(json, 'warehouseName'),
        locationCode: JsonReader.string(json, 'locationCode'),
        initialWeightKg: JsonReader.decimal(json, 'initialWeightKg') ?? 0,
        remainingWeightKg: JsonReader.decimal(json, 'remainingWeightKg') ?? 0,
        qualityStatus: JsonReader.string(json, 'qualityStatus'),
        inboundDate: _date(json, 'inboundDate'),
      );
}

/// Phiếu thu mua lúa đầu nguồn của lô.
class TraceabilityPurchase {
  const TraceabilityPurchase({
    required this.receiptId,
    required this.receiptCode,
    required this.farmerId,
    required this.actualWeightKg,
    this.paddyLotCode,
    this.farmerCode,
    this.farmerName,
    this.riceVarietyName,
    this.warehouseName,
    this.receiptDate,
    this.bagCount,
  });

  final int receiptId;
  final String receiptCode;
  final String? paddyLotCode;
  final int farmerId;
  final String? farmerCode;
  final String? farmerName;
  final String? riceVarietyName;
  final String? warehouseName;
  final DateTime? receiptDate;
  final double actualWeightKg;
  final int? bagCount;

  factory TraceabilityPurchase.fromJson(Map<String, dynamic> json) =>
      TraceabilityPurchase(
        receiptId: JsonReader.integer(json, 'receiptId') ?? 0,
        receiptCode: JsonReader.string(json, 'receiptCode') ?? '',
        paddyLotCode: JsonReader.string(json, 'paddyLotCode'),
        farmerId: JsonReader.integer(json, 'farmerId') ?? 0,
        farmerCode: JsonReader.string(json, 'farmerCode'),
        farmerName: JsonReader.string(json, 'farmerName'),
        riceVarietyName: JsonReader.string(json, 'riceVarietyName'),
        warehouseName: JsonReader.string(json, 'warehouseName'),
        receiptDate: _date(json, 'receiptDate'),
        actualWeightKg: JsonReader.decimal(json, 'actualWeightKg') ?? 0,
        bagCount: JsonReader.integer(json, 'bagCount'),
      );
}

/// Lần kiểm định chất lượng của lô.
class TraceabilityInspection {
  const TraceabilityInspection({
    required this.inspectionId,
    required this.paddyLotId,
    required this.passedInspection,
    this.paddyLotCode,
    this.inspectedAt,
    this.moisturePercent,
    this.impurityPercent,
    this.moldLevel,
    this.pestLevel,
    this.packagingStatus,
    this.handling,
    this.resultName,
    this.inspectorName,
    this.note,
  });

  final int inspectionId;
  final int paddyLotId;
  final String? paddyLotCode;
  final DateTime? inspectedAt;
  final double? moisturePercent;
  final double? impurityPercent;
  final String? moldLevel;
  final String? pestLevel;
  final String? packagingStatus;
  final String? handling;
  final bool passedInspection;
  final String? resultName;
  final String? inspectorName;
  final String? note;

  factory TraceabilityInspection.fromJson(Map<String, dynamic> json) =>
      TraceabilityInspection(
        inspectionId: JsonReader.integer(json, 'inspectionId') ?? 0,
        paddyLotId: JsonReader.integer(json, 'paddyLotId') ?? 0,
        paddyLotCode: JsonReader.string(json, 'paddyLotCode'),
        inspectedAt: _date(json, 'inspectedAt'),
        moisturePercent: JsonReader.decimal(json, 'moisturePercent'),
        impurityPercent: JsonReader.decimal(json, 'impurityPercent'),
        moldLevel: JsonReader.string(json, 'moldLevel'),
        pestLevel: JsonReader.string(json, 'pestLevel'),
        packagingStatus: JsonReader.string(json, 'packagingStatus'),
        handling: JsonReader.string(json, 'handling'),
        passedInspection:
            JsonReader.boolean(json, 'passedInspection') ?? false,
        resultName: JsonReader.string(json, 'resultName'),
        inspectorName: JsonReader.string(json, 'inspectorName'),
        note: JsonReader.string(json, 'note'),
      );
}

class TraceabilityMillingInput {
  const TraceabilityMillingInput({
    required this.paddyLotId,
    required this.consumedWeightKg,
    this.paddyLotCode,
    this.lotType,
    this.sku,
    this.locationCode,
    this.reservedWeightKg,
  });

  final int paddyLotId;
  final String? paddyLotCode;
  final String? lotType;
  final String? sku;
  final String? locationCode;
  final double? reservedWeightKg;
  final double consumedWeightKg;

  factory TraceabilityMillingInput.fromJson(Map<String, dynamic> json) =>
      TraceabilityMillingInput(
        paddyLotId: JsonReader.integer(json, 'paddyLotId') ?? 0,
        paddyLotCode: JsonReader.string(json, 'paddyLotCode'),
        lotType: JsonReader.string(json, 'lotType'),
        sku: JsonReader.string(json, 'sku'),
        locationCode: JsonReader.string(json, 'locationCode'),
        reservedWeightKg: JsonReader.decimal(json, 'reservedWeightKg'),
        consumedWeightKg: JsonReader.decimal(json, 'consumedWeightKg') ?? 0,
      );
}

class TraceabilityMillingOutput {
  const TraceabilityMillingOutput({
    required this.outputType,
    required this.outputWeightKg,
    required this.isByproduct,
    this.outputLotId,
    this.outputLotCode,
    this.sku,
    this.productVariantName,
    this.bagCount,
    this.locationCode,
  });

  final int? outputLotId;
  final String? outputLotCode;
  final String? sku;
  final String? productVariantName;
  final String outputType;
  final double outputWeightKg;
  final int? bagCount;
  final bool isByproduct;
  final String? locationCode;

  factory TraceabilityMillingOutput.fromJson(Map<String, dynamic> json) =>
      TraceabilityMillingOutput(
        outputLotId: JsonReader.integer(json, 'outputLotId'),
        outputLotCode: JsonReader.string(json, 'outputLotCode'),
        sku: JsonReader.string(json, 'sku'),
        productVariantName: JsonReader.string(json, 'productVariantName'),
        outputType: JsonReader.string(json, 'outputType') ?? '',
        outputWeightKg: JsonReader.decimal(json, 'outputWeightKg') ?? 0,
        bagCount: JsonReader.integer(json, 'bagCount'),
        isByproduct: JsonReader.boolean(json, 'isByproduct') ?? false,
        locationCode: JsonReader.string(json, 'locationCode'),
      );
}

/// Lệnh xay xát mà lô này tham gia (làm đầu vào hoặc sinh ra từ đó).
class TraceabilityMilling {
  const TraceabilityMilling({
    required this.millingOrderId,
    required this.millingCode,
    required this.yieldRateUsed,
    required this.computedPaddyKg,
    required this.totalRiceOutputKg,
    required this.inputs,
    required this.outputs,
    this.statusName,
    this.statusCode,
    this.warehouseName,
    this.byproductKg,
    this.lossKg,
    this.startedAt,
    this.completedAt,
  });

  final int millingOrderId;
  final String millingCode;
  final String? statusName;
  final String? statusCode;
  final String? warehouseName;
  final double yieldRateUsed;
  final double computedPaddyKg;
  final double totalRiceOutputKg;
  final double? byproductKg;
  final double? lossKg;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<TraceabilityMillingInput> inputs;
  final List<TraceabilityMillingOutput> outputs;

  factory TraceabilityMilling.fromJson(Map<String, dynamic> json) =>
      TraceabilityMilling(
        millingOrderId: JsonReader.integer(json, 'millingOrderId') ?? 0,
        millingCode: JsonReader.string(json, 'millingCode') ?? '',
        statusName: JsonReader.string(json, 'statusName'),
        statusCode: JsonReader.string(json, 'statusCode'),
        warehouseName: JsonReader.string(json, 'warehouseName'),
        yieldRateUsed: JsonReader.decimal(json, 'yieldRateUsed') ?? 0,
        computedPaddyKg: JsonReader.decimal(json, 'computedPaddyKg') ?? 0,
        totalRiceOutputKg: JsonReader.decimal(json, 'totalRiceOutputKg') ?? 0,
        byproductKg: JsonReader.decimal(json, 'byproductKg'),
        lossKg: JsonReader.decimal(json, 'lossKg'),
        startedAt: _date(json, 'startedAt'),
        completedAt: _date(json, 'completedAt'),
        inputs: [
          for (final item in JsonReader.list(json, 'inputs') ?? const [])
            if (item is Map<String, dynamic>)
              TraceabilityMillingInput.fromJson(item),
        ],
        outputs: [
          for (final item in JsonReader.list(json, 'outputs') ?? const [])
            if (item is Map<String, dynamic>)
              TraceabilityMillingOutput.fromJson(item),
        ],
      );
}

class TraceabilityOutboundAllocation {
  const TraceabilityOutboundAllocation({
    required this.allocationId,
    required this.quantityAllocatedKg,
    required this.quantityPickedKg,
    this.paddyLotId,
    this.paddyLotCode,
    this.sku,
    this.productVariantName,
    this.locationCode,
  });

  final int allocationId;
  final int? paddyLotId;
  final String? paddyLotCode;
  final String? sku;
  final String? productVariantName;
  final String? locationCode;
  final double quantityAllocatedKg;
  final double quantityPickedKg;

  factory TraceabilityOutboundAllocation.fromJson(Map<String, dynamic> json) =>
      TraceabilityOutboundAllocation(
        allocationId: JsonReader.integer(json, 'allocationId') ?? 0,
        paddyLotId: JsonReader.integer(json, 'paddyLotId'),
        paddyLotCode: JsonReader.string(json, 'paddyLotCode'),
        sku: JsonReader.string(json, 'sku'),
        productVariantName: JsonReader.string(json, 'productVariantName'),
        locationCode: JsonReader.string(json, 'locationCode'),
        quantityAllocatedKg:
            JsonReader.decimal(json, 'quantityAllocatedKg') ?? 0,
        quantityPickedKg: JsonReader.decimal(json, 'quantityPickedKg') ?? 0,
      );
}

/// Lô đã đi ra thị trường qua phiếu xuất nào, tới khách nào.
class TraceabilityOutbound {
  const TraceabilityOutbound({
    required this.outboundOrderId,
    required this.salesOrderId,
    required this.allocations,
    this.outboundStatusName,
    this.outboundStatusCode,
    this.completedDate,
    this.warehouseName,
    this.salesOrderCode,
    this.salesOrderStatusName,
    this.salesOrderDate,
    this.channel,
    this.customerId,
    this.customerCode,
    this.customerName,
  });

  final int outboundOrderId;
  final String? outboundStatusName;
  final String? outboundStatusCode;
  final DateTime? completedDate;
  final String? warehouseName;
  final int salesOrderId;
  final String? salesOrderCode;
  final String? salesOrderStatusName;
  final DateTime? salesOrderDate;
  final String? channel;
  final int? customerId;
  final String? customerCode;
  final String? customerName;
  final List<TraceabilityOutboundAllocation> allocations;

  double get totalPickedKg =>
      allocations.fold(0.0, (sum, a) => sum + a.quantityPickedKg);

  factory TraceabilityOutbound.fromJson(Map<String, dynamic> json) =>
      TraceabilityOutbound(
        outboundOrderId: JsonReader.integer(json, 'outboundOrderId') ?? 0,
        outboundStatusName: JsonReader.string(json, 'outboundStatusName'),
        outboundStatusCode: JsonReader.string(json, 'outboundStatusCode'),
        completedDate: _date(json, 'completedDate'),
        warehouseName: JsonReader.string(json, 'warehouseName'),
        salesOrderId: JsonReader.integer(json, 'salesOrderId') ?? 0,
        salesOrderCode: JsonReader.string(json, 'salesOrderCode'),
        salesOrderStatusName: JsonReader.string(json, 'salesOrderStatusName'),
        salesOrderDate: _date(json, 'salesOrderDate'),
        channel: JsonReader.string(json, 'channel'),
        customerId: JsonReader.integer(json, 'customerId'),
        customerCode: JsonReader.string(json, 'customerCode'),
        customerName: JsonReader.string(json, 'customerName'),
        allocations: [
          for (final item in JsonReader.list(json, 'allocations') ?? const [])
            if (item is Map<String, dynamic>)
              TraceabilityOutboundAllocation.fromJson(item),
        ],
      );
}

/// Bảng cân đối khối lượng của cả chuỗi: mua vào → xay → bán ra → còn lại.
class TraceabilitySummary {
  const TraceabilitySummary({
    this.relatedLotCount = 0,
    this.purchaseReceiptCount = 0,
    this.inspectionCount = 0,
    this.millingOrderCount = 0,
    this.outboundOrderCount = 0,
    this.purchasedWeightKg = 0,
    this.millingInputWeightKg = 0,
    this.millingRiceOutputWeightKg = 0,
    this.millingByproductWeightKg = 0,
    this.millingLossWeightKg = 0,
    this.allocatedOutboundWeightKg = 0,
    this.dispatchedWeightKg = 0,
    this.currentRemainingWeightKg = 0,
  });

  final int relatedLotCount;
  final int purchaseReceiptCount;
  final int inspectionCount;
  final int millingOrderCount;
  final int outboundOrderCount;
  final double purchasedWeightKg;
  final double millingInputWeightKg;
  final double millingRiceOutputWeightKg;
  final double millingByproductWeightKg;
  final double millingLossWeightKg;
  final double allocatedOutboundWeightKg;
  final double dispatchedWeightKg;
  final double currentRemainingWeightKg;

  /// Tỉ lệ thu hồi gạo thực tế trên lượng lúa đưa vào xay (0 khi chưa xay).
  double get actualYieldRate => millingInputWeightKg <= 0
      ? 0
      : millingRiceOutputWeightKg / millingInputWeightKg;

  factory TraceabilitySummary.fromJson(Map<String, dynamic> json) =>
      TraceabilitySummary(
        relatedLotCount: JsonReader.integer(json, 'relatedLotCount') ?? 0,
        purchaseReceiptCount:
            JsonReader.integer(json, 'purchaseReceiptCount') ?? 0,
        inspectionCount: JsonReader.integer(json, 'inspectionCount') ?? 0,
        millingOrderCount: JsonReader.integer(json, 'millingOrderCount') ?? 0,
        outboundOrderCount: JsonReader.integer(json, 'outboundOrderCount') ?? 0,
        purchasedWeightKg: JsonReader.decimal(json, 'purchasedWeightKg') ?? 0,
        millingInputWeightKg:
            JsonReader.decimal(json, 'millingInputWeightKg') ?? 0,
        millingRiceOutputWeightKg:
            JsonReader.decimal(json, 'millingRiceOutputWeightKg') ?? 0,
        millingByproductWeightKg:
            JsonReader.decimal(json, 'millingByproductWeightKg') ?? 0,
        millingLossWeightKg:
            JsonReader.decimal(json, 'millingLossWeightKg') ?? 0,
        allocatedOutboundWeightKg:
            JsonReader.decimal(json, 'allocatedOutboundWeightKg') ?? 0,
        dispatchedWeightKg:
            JsonReader.decimal(json, 'dispatchedWeightKg') ?? 0,
        currentRemainingWeightKg:
            JsonReader.decimal(json, 'currentRemainingWeightKg') ?? 0,
      );
}

/// Toàn bộ hồ sơ truy xuất nguồn gốc của một lô.
///
/// Trước đây lớp này CHỈ đọc `timeline` nên bỏ phí gần hết payload backend gửi
/// về (lô liên quan, thu mua, kiểm định, xay xát, bán ra, tổng hợp khối lượng).
/// Nay map đủ mọi nhánh của `PaddyLotTraceabilityDto`.
class PaddyLotTraceability {
  const PaddyLotTraceability({
    required this.requestedLotId,
    required this.requestedLotCode,
    required this.events,
    required this.isTruncated,
    this.relatedLots = const [],
    this.purchases = const [],
    this.inspections = const [],
    this.millingOrders = const [],
    this.outboundSales = const [],
    this.summary = const TraceabilitySummary(),
  });

  final int requestedLotId;
  final String requestedLotCode;
  final List<TraceabilityEvent> events;
  final bool isTruncated;
  final List<TraceabilityLot> relatedLots;
  final List<TraceabilityPurchase> purchases;
  final List<TraceabilityInspection> inspections;
  final List<TraceabilityMilling> millingOrders;
  final List<TraceabilityOutbound> outboundSales;
  final TraceabilitySummary summary;

  /// Lô được tra cứu, lấy trong danh sách lô liên quan (nếu backend có trả).
  TraceabilityLot? get selfLot {
    for (final lot in relatedLots) {
      if (lot.id == requestedLotId || lot.isSelf) return lot;
    }
    return null;
  }

  bool get hasDetail =>
      relatedLots.isNotEmpty ||
      purchases.isNotEmpty ||
      inspections.isNotEmpty ||
      millingOrders.isNotEmpty ||
      outboundSales.isNotEmpty;

  factory PaddyLotTraceability.fromJson(Map<String, dynamic> json) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) build) => [
          for (final item in JsonReader.list(json, key) ?? const [])
            if (item is Map<String, dynamic>) build(item),
        ];

    final summary = JsonReader.map(json, 'summary');
    return PaddyLotTraceability(
      requestedLotId: JsonReader.integer(json, 'requestedLotId') ?? 0,
      requestedLotCode: JsonReader.string(json, 'requestedLotCode') ?? '',
      isTruncated: JsonReader.boolean(json, 'isTruncated') ?? false,
      events: parse('timeline', TraceabilityEvent.fromJson),
      relatedLots: parse('relatedLots', TraceabilityLot.fromJson),
      purchases: parse('purchases', TraceabilityPurchase.fromJson),
      inspections:
          parse('qualityInspections', TraceabilityInspection.fromJson),
      millingOrders: parse('millingOrders', TraceabilityMilling.fromJson),
      outboundSales: parse('outboundSales', TraceabilityOutbound.fromJson),
      summary: summary == null
          ? const TraceabilitySummary()
          : TraceabilitySummary.fromJson(summary),
    );
  }
}

DateTime? _date(Map<String, dynamic> json, String key) {
  final value = JsonReader.string(json, key);
  return value == null ? null : DateTime.tryParse(value)?.toLocal();
}
