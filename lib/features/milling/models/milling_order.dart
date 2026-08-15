import '../../../core/api/json_reader.dart';

class MillingFilterOption {
  const MillingFilterOption({
    required this.id,
    required this.name,
    this.code,
    this.color,
  });

  final int id;
  final String name;
  final String? code;
  final String? color;
}

/// A single recorded bag produced by a milling order.
class MillingBag {
  const MillingBag({
    required this.index,
    required this.weightKg,
  });

  final int index;
  final double weightKg;
}

enum MillingScaleMode { iot, manual }

class MillingProductOption {
  const MillingProductOption({
    required this.id,
    required this.name,
    required this.sku,
    required this.outputType,
    this.targetWeightKg,
  });

  final int id;
  final String name;
  final String sku;
  final String outputType;
  final double? targetWeightKg;
}

class MillingPaddyLotOption {
  const MillingPaddyLotOption({
    required this.id,
    required this.code,
    required this.warehouseId,
    required this.warehouseName,
    required this.remainingWeightKg,
    this.locationId,
    this.locationCode,
    this.riceVarietyId,
    this.riceVarietyName,
  });

  final int id;
  final String code;
  final int warehouseId;
  final String warehouseName;
  final int? locationId;
  final String? locationCode;
  final int? riceVarietyId;
  final String? riceVarietyName;
  final double remainingWeightKg;
}

class MillingOrderInput {
  const MillingOrderInput({
    required this.id,
    required this.paddyLotId,
    required this.consumedWeightKg,
    this.lotCode,
    this.locationId,
    this.locationCode,
    this.reservedWeightKg,
    this.note,
    this.bags = const [],
  });

  final int id;
  final int paddyLotId;
  final String? lotCode;
  final int? locationId;
  final String? locationCode;
  final double consumedWeightKg;
  final double? reservedWeightKg;
  final String? note;
  final List<MillingSelectedBag> bags;

  factory MillingOrderInput.fromJson(Map<String, dynamic> json) {
    return MillingOrderInput(
      id: JsonReader.integer(json, 'id') ?? 0,
      paddyLotId: JsonReader.integer(json, 'paddyLotId') ?? 0,
      lotCode: JsonReader.string(json, 'lotCode'),
      locationId: JsonReader.integer(json, 'locationId'),
      locationCode: JsonReader.string(json, 'locationCode'),
      consumedWeightKg: JsonReader.decimal(json, 'consumedWeightKg') ?? 0,
      reservedWeightKg: JsonReader.decimal(json, 'reservedWeightKg'),
      note: JsonReader.string(json, 'note'),
      bags: [
        for (final item in JsonReader.list(json, 'bags') ?? const [])
          if (item is Map<String, dynamic>) MillingSelectedBag.fromJson(item),
      ],
    );
  }
}

class MillingSelectedBag {
  const MillingSelectedBag({
    required this.bagId,
    required this.bagNo,
    required this.weightKg,
    required this.stackOrder,
    required this.status,
  });

  final int bagId;
  final int bagNo;
  final double weightKg;
  final int stackOrder;
  final String status;

  factory MillingSelectedBag.fromJson(Map<String, dynamic> json) {
    return MillingSelectedBag(
      bagId: JsonReader.integer(json, 'bagId') ?? 0,
      bagNo: JsonReader.integer(json, 'bagNo') ?? 0,
      weightKg: JsonReader.decimal(json, 'weightKg') ?? 0,
      stackOrder: JsonReader.integer(json, 'stackOrder') ?? 0,
      status: JsonReader.string(json, 'status') ?? '',
    );
  }
}

class MillingOrderOutput {
  const MillingOrderOutput({
    required this.id,
    required this.productVariantId,
    required this.outputWeightKg,
    required this.isByproduct,
    this.sku,
    this.outputLotId,
    this.locationId,
    this.outputType,
    this.bagCount,
    this.unitCost,
  });

  final int id;
  final int productVariantId;
  final String? sku;
  final int? outputLotId;
  final int? locationId;
  final String? outputType;
  final double outputWeightKg;
  final int? bagCount;
  final bool isByproduct;
  final double? unitCost;

  factory MillingOrderOutput.fromJson(Map<String, dynamic> json) {
    return MillingOrderOutput(
      id: JsonReader.integer(json, 'id') ?? 0,
      productVariantId: JsonReader.integer(json, 'productVariantId') ?? 0,
      sku: JsonReader.string(json, 'sku') ?? JsonReader.string(json, 'SKU'),
      outputLotId: JsonReader.integer(json, 'outputLotId'),
      locationId: JsonReader.integer(json, 'locationId'),
      outputType: JsonReader.string(json, 'outputType'),
      outputWeightKg: JsonReader.decimal(json, 'outputWeightKg') ?? 0,
      bagCount: JsonReader.integer(json, 'bagCount'),
      isByproduct: JsonReader.boolean(json, 'isByproduct') ?? false,
      unitCost: JsonReader.decimal(json, 'unitCost'),
    );
  }
}

class MillingOrderPage {
  const MillingOrderPage({
    required this.orders,
    required this.recordsTotal,
    required this.recordsFiltered,
  });

  final List<MillingOrder> orders;
  final int recordsTotal;
  final int recordsFiltered;
}

class MillingSourceColumn {
  const MillingSourceColumn({
    required this.locationId,
    this.locationCode,
    required this.bags,
  });

  final int locationId;
  final String? locationCode;
  final List<MillingSourceBag> bags;

  double get totalWeightKg => bags
      .where((bag) => bag.selected)
      .fold<double>(0, (sum, bag) => sum + bag.weightKg);

  List<int> get selectedBagIds => bags
      .where((bag) => bag.selected)
      .map((bag) => bag.id)
      .toList(growable: false);
}

class MillingSourceBag {
  const MillingSourceBag({
    required this.id,
    required this.bagNo,
    required this.weightKg,
    required this.status,
    this.selected = false,
  });

  final int id;
  final int bagNo;
  final double weightKg;
  final String status;
  final bool selected;

  bool get selectable => status.trim().toUpperCase() == 'STORED';

  MillingSourceBag copyWith({bool? selected}) => MillingSourceBag(
        id: id,
        bagNo: bagNo,
        weightKg: weightKg,
        status: status,
        selected: selected ?? this.selected,
      );
}

class MillingSourceSuggestion {
  const MillingSourceSuggestion({
    required this.requiredWeightKg,
    required this.columns,
    this.suggestedWeightKg = 0,
    this.missingWeightKg = 0,
    this.readOnly = false,
  });

  final double requiredWeightKg;
  final List<MillingSourceColumn> columns;

  /// Khối lượng backend gợi ý lấy được ngay (tổng các bao đã chọn sẵn).
  final double suggestedWeightKg;

  /// Phần backend không tìm được nguồn lấy ngay — web cảnh báo "còn thiếu".
  final double missingWeightKg;

  /// Dựng từ nguồn ĐÃ GIỮ của lệnh (chỉ xem), không phải từ API gợi ý.
  final bool readOnly;

  bool get isComplete => missingWeightKg <= 0.0005;

  double get selectedWeightKg => columns.fold<double>(
        0,
        (sum, column) => sum + column.totalWeightKg,
      );

  /// Nguồn lúa ĐÃ GIỮ của một lệnh, dựng từ `inputs` của chi tiết lệnh.
  ///
  /// Dùng cho lệnh đang xay: backend chỉ gợi ý nguồn cho lệnh Nháp/Đã giữ nên
  /// gọi `source-suggestions` ở trạng thái này sẽ trả 422.
  factory MillingSourceSuggestion.fromOrderInputs(MillingOrder order) {
    final grouped = <int, List<MillingSourceBag>>{};
    final codes = <int, String?>{};
    for (final input in order.inputs) {
      final locationId = input.locationId ?? 0;
      codes[locationId] ??= input.locationCode ?? input.lotCode;
      grouped.putIfAbsent(locationId, () => <MillingSourceBag>[]).addAll([
        for (final bag in input.bags)
          MillingSourceBag(
            id: bag.bagId,
            bagNo: bag.bagNo,
            weightKg: bag.weightKg,
            status: 'Stored',
            selected: true,
          ),
      ]);
    }
    final columns = [
      for (final entry in grouped.entries)
        MillingSourceColumn(
          locationId: entry.key,
          locationCode: codes[entry.key],
          bags: entry.value,
        ),
    ];
    final total = columns.fold<double>(
      0,
      (sum, column) => sum + column.totalWeightKg,
    );
    return MillingSourceSuggestion(
      requiredWeightKg:
          order.computedPaddyKg > 0 ? order.computedPaddyKg : total,
      columns: columns,
      suggestedWeightKg: total,
      readOnly: true,
    );
  }
}

/// Mobile-facing data required to finish and pack a milling order.
class MillingOrder {
  const MillingOrder({
    required this.id,
    required this.millingCode,
    required this.inputLotCode,
    required this.inputWeightKg,
    required this.warehouseZone,
    required this.locationCode,
    required this.scaleCode,
    required this.riceBags,
    required this.branBags,
    this.brokenBags = const [],
    this.scaleMode = MillingScaleMode.iot,
    this.riceProductVariantId = 0,
    this.branProductVariantId = 0,
    this.brokenProductVariantId = 0,
    this.statusId = 0,
    this.statusName,
    this.statusCode,
    this.warehouseId = 0,
    this.warehouseName,
    this.riceVarietyId,
    this.riceVarietyName,
    this.reason,
    this.salesOrderId,
    this.yieldRateUsed = 0,
    this.totalRiceOutputKg = 0,
    this.computedPaddyKg = 0,
    this.actualPaddyInputKg,
    this.actualYieldRate,
    this.byproductKg,
    this.lossKg,
    this.machineRef,
    this.operatorId,
    this.startedAt,
    this.completedAt,
    this.totalCost,
    this.millingCost,
    this.incidentalCost,
    this.moisturePercent,
    this.expectedCompletionDate,
    this.createdDate,
    this.lastModifiedDate,
    this.inputs = const [],
    this.outputs = const [],
  });

  final int id;
  final String millingCode;
  final String inputLotCode;
  final double inputWeightKg;
  final String warehouseZone;
  final String locationCode;
  final String scaleCode;
  final List<MillingBag> riceBags;
  final List<MillingBag> branBags;
  final List<MillingBag> brokenBags;
  final MillingScaleMode scaleMode;
  final int riceProductVariantId;
  final int branProductVariantId;
  final int brokenProductVariantId;
  final int statusId;
  final String? statusName;
  final String? statusCode;
  final int warehouseId;
  final String? warehouseName;
  final int? riceVarietyId;
  final String? riceVarietyName;
  final String? reason;
  final int? salesOrderId;
  final double yieldRateUsed;
  final double totalRiceOutputKg;
  final double computedPaddyKg;
  final double? actualPaddyInputKg;
  final double? actualYieldRate;
  final double? byproductKg;
  final double? lossKg;
  final String? machineRef;
  final int? operatorId;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double? totalCost;
  final double? millingCost;
  final double? incidentalCost;
  final double? moisturePercent;
  final DateTime? expectedCompletionDate;
  final DateTime? createdDate;
  final DateTime? lastModifiedDate;
  final List<MillingOrderInput> inputs;
  final List<MillingOrderOutput> outputs;

  factory MillingOrder.fromJson(Map<String, dynamic> json) {
    final id = JsonReader.integer(json, 'id') ?? 0;
    final inputs = [
      for (final item in JsonReader.list(json, 'inputs') ?? const [])
        if (item is Map<String, dynamic>) MillingOrderInput.fromJson(item),
    ];
    final outputs = [
      for (final item in JsonReader.list(json, 'outputs') ?? const [])
        if (item is Map<String, dynamic>) MillingOrderOutput.fromJson(item),
    ];
    final firstInput = inputs.firstOrNull;
    final machineRef = JsonReader.string(json, 'machineRef');
    final computedPaddyKg = JsonReader.decimal(json, 'computedPaddyKg') ?? 0;
    final actualPaddyInputKg = JsonReader.decimal(json, 'actualPaddyInputKg');
    final consumedInputKg = inputs.fold<double>(
      0,
      (total, input) => total + input.consumedWeightKg,
    );
    final mappedInputWeightKg = actualPaddyInputKg ??
        (consumedInputKg > 0 ? consumedInputKg : computedPaddyKg);
    final statusId = JsonReader.integer(json, 'statusId') ?? 0;
    final statusCode = JsonReader.string(json, 'statusCode') ??
        _statusCodeFromId(statusId);

    return MillingOrder(
      id: id,
      millingCode: JsonReader.string(json, 'millingCode') ?? 'MO-$id',
      inputLotCode: firstInput?.lotCode ??
          JsonReader.string(json, 'inputLotCode') ??
          'Lô chưa xác định',
      inputWeightKg: mappedInputWeightKg,
      warehouseZone:
          JsonReader.string(json, 'warehouseName') ?? 'Kho chưa xác định',
      locationCode: firstInput?.locationCode ??
          (firstInput?.locationId == null
              ? 'Chưa có vị trí'
              : '${firstInput?.locationId}'),
      scaleCode: machineRef ?? 'Cân thủ công',
      riceBags: const [],
      branBags: const [],
      brokenBags: const [],
      riceProductVariantId: _outputVariantId(outputs, 'RICE'),
      branProductVariantId: _outputVariantId(outputs, 'BRAN'),
      brokenProductVariantId: _outputVariantId(outputs, 'BROKEN'),
      statusId: statusId,
      statusName: JsonReader.string(json, 'statusName'),
      statusCode: statusCode,
      warehouseId: JsonReader.integer(json, 'warehouseId') ?? 0,
      warehouseName: JsonReader.string(json, 'warehouseName'),
      riceVarietyId: JsonReader.integer(json, 'riceVarietyId'),
      riceVarietyName: JsonReader.string(json, 'riceVarietyName'),
      reason: JsonReader.string(json, 'reason'),
      salesOrderId: JsonReader.integer(json, 'salesOrderId'),
      yieldRateUsed: JsonReader.decimal(json, 'yieldRateUsed') ?? 0,
      totalRiceOutputKg: JsonReader.decimal(json, 'totalRiceOutputKg') ?? 0,
      computedPaddyKg: computedPaddyKg,
      actualPaddyInputKg: actualPaddyInputKg,
      actualYieldRate: JsonReader.decimal(json, 'actualYieldRate'),
      byproductKg: JsonReader.decimal(json, 'byproductKg'),
      lossKg: JsonReader.decimal(json, 'lossKg'),
      machineRef: machineRef,
      operatorId: JsonReader.integer(json, 'operatorId'),
      startedAt: _date(json, 'startedAt'),
      completedAt: _date(json, 'completedAt'),
      totalCost: JsonReader.decimal(json, 'totalCost'),
      millingCost: JsonReader.decimal(json, 'millingCost'),
      incidentalCost: JsonReader.decimal(json, 'incidentalCost'),
      moisturePercent: JsonReader.decimal(json, 'moisturePercent'),
      expectedCompletionDate: _date(json, 'expectedCompletionDate'),
      createdDate: _date(json, 'createdDate'),
      lastModifiedDate: _date(json, 'lastModifiedDate'),
      inputs: inputs,
      outputs: outputs,
    );
  }

  // The paged milling-order contract currently exposes statusId/statusName,
  // while the detail contract also exposes statusCode. Keep the mapping
  // limited to the backend's seeded IDs; unknown IDs must remain unknown.
  static String? _statusCodeFromId(int statusId) => switch (statusId) {
        1 => 'DRAFT',
        2 => 'RESERVED',
        3 => 'IN_PROGRESS',
        5 => 'COMPLETED',
        6 => 'CANCELLED',
        _ => null,
      };

  MillingOrder copyWith({
    List<MillingBag>? riceBags,
    List<MillingBag>? branBags,
    List<MillingBag>? brokenBags,
    MillingScaleMode? scaleMode,
    int? riceProductVariantId,
    int? branProductVariantId,
    int? brokenProductVariantId,
  }) {
    return MillingOrder(
      id: id,
      millingCode: millingCode,
      inputLotCode: inputLotCode,
      inputWeightKg: inputWeightKg,
      warehouseZone: warehouseZone,
      locationCode: locationCode,
      scaleCode: scaleCode,
      riceBags: riceBags ?? this.riceBags,
      branBags: branBags ?? this.branBags,
      brokenBags: brokenBags ?? this.brokenBags,
      scaleMode: scaleMode ?? this.scaleMode,
      riceProductVariantId: riceProductVariantId ?? this.riceProductVariantId,
      branProductVariantId: branProductVariantId ?? this.branProductVariantId,
      brokenProductVariantId:
          brokenProductVariantId ?? this.brokenProductVariantId,
      statusId: statusId,
      statusName: statusName,
      statusCode: statusCode,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      riceVarietyId: riceVarietyId,
      riceVarietyName: riceVarietyName,
      reason: reason,
      salesOrderId: salesOrderId,
      yieldRateUsed: yieldRateUsed,
      totalRiceOutputKg: totalRiceOutputKg,
      computedPaddyKg: computedPaddyKg,
      actualPaddyInputKg: actualPaddyInputKg,
      actualYieldRate: actualYieldRate,
      byproductKg: byproductKg,
      lossKg: lossKg,
      machineRef: machineRef,
      operatorId: operatorId,
      startedAt: startedAt,
      completedAt: completedAt,
      totalCost: totalCost,
      millingCost: millingCost,
      incidentalCost: incidentalCost,
      moisturePercent: moisturePercent,
      expectedCompletionDate: expectedCompletionDate,
      createdDate: createdDate,
      lastModifiedDate: lastModifiedDate,
      inputs: inputs,
      outputs: outputs,
    );
  }

  /// Total weight of finished rice recorded from all rice bags.
  double get totalRiceKg =>
      riceBags.fold(0, (total, bag) => total + bag.weightKg);

  /// Total weight of bran recorded as a milling by-product.
  double get totalBranKg =>
      branBags.fold(0, (total, bag) => total + bag.weightKg);

  double get totalBrokenKg =>
      brokenBags.fold(0, (total, bag) => total + bag.weightKg);

  /// Finished-rice yield compared with the paddy input weight.
  double get riceYieldPercent =>
      inputWeightKg == 0 ? 0 : totalRiceKg / inputWeightKg * 100;

  static int _outputVariantId(List<MillingOrderOutput> outputs, String type) {
    for (final item in outputs) {
      if ((item.outputType ?? '').toUpperCase() == type) {
        return item.productVariantId;
      }
    }
    return 0;
  }

  static DateTime? _date(Map<String, dynamic> json, String key) {
    final value = JsonReader.value(json, key);
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
