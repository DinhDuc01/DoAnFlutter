import '../../../core/api/json_reader.dart';

class StockTakeSummary {
  const StockTakeSummary({
    required this.id,
    required this.warehouseId,
    required this.stockTakeStatusId,
    required this.stCode,
    this.note,
    this.startedDate,
    this.completedDate,
    this.createdDate,
    this.warehouseName,
    this.stockTakeStatusCode,
    this.stockTakeStatusName,
    this.stockTakeStatusColor,
    this.createdByName,
    required this.scopeDisplay,
    required this.varianceLineCount,
    required this.netVarianceKg,
  });

  final int id;
  final int warehouseId;
  final int stockTakeStatusId;
  final String stCode;
  final String? note;
  final DateTime? startedDate;
  final DateTime? completedDate;
  final DateTime? createdDate;
  final String? warehouseName;
  final String? stockTakeStatusCode;
  final String? stockTakeStatusName;
  final String? stockTakeStatusColor;
  final String? createdByName;
  final String scopeDisplay;
  final int varianceLineCount;
  final double netVarianceKg;

  factory StockTakeSummary.fromJson(Map<String, dynamic> json) {
    return StockTakeSummary(
      id: JsonReader.integer(json, 'id') ?? 0,
      warehouseId: JsonReader.integer(json, 'warehouseId') ?? 0,
      stockTakeStatusId: JsonReader.integer(json, 'stockTakeStatusId') ?? 0,
      stCode: JsonReader.string(json, 'stCode') ?? '',
      note: JsonReader.string(json, 'note'),
      startedDate: _parseDate(json, 'startedDate'),
      completedDate: _parseDate(json, 'completedDate'),
      createdDate: _parseDate(json, 'createdDate'),
      warehouseName: JsonReader.string(json, 'warehouseName'),
      stockTakeStatusCode: JsonReader.string(json, 'stockTakeStatusCode'),
      stockTakeStatusName: JsonReader.string(json, 'stockTakeStatusName'),
      stockTakeStatusColor: JsonReader.string(json, 'stockTakeStatusColor'),
      createdByName: JsonReader.string(json, 'createdByName'),
      scopeDisplay: JsonReader.string(json, 'scopeDisplay') ?? '',
      varianceLineCount: JsonReader.integer(json, 'varianceLineCount') ?? 0,
      netVarianceKg: JsonReader.decimal(json, 'netVarianceKg') ?? 0.0,
    );
  }

  static DateTime? _parseDate(Map<String, dynamic> json, String key) {
    final val = JsonReader.string(json, key);
    return val != null ? DateTime.tryParse(val) : null;
  }
}

class StockTakeDetail {
  const StockTakeDetail({
    required this.id,
    required this.warehouseId,
    required this.stockTakeStatusId,
    required this.stCode,
    this.note,
    this.startedDate,
    this.completedDate,
    this.approvedByUserId,
    this.approveNote,
    required this.createdDate,
    this.lastModifiedDate,
    this.warehouseName,
    this.stockTakeStatusCode,
    this.stockTakeStatusName,
    this.stockTakeStatusColor,
    this.createdByUserId,
    this.createdByName,
    required this.scopeDisplay,
    required this.varianceLineCount,
    required this.netVarianceKg,
    required this.items,
  });

  final int id;
  final int warehouseId;
  final int stockTakeStatusId;
  final String stCode;
  final String? note;
  final DateTime? startedDate;
  final DateTime? completedDate;
  final int? approvedByUserId;
  final String? approveNote;
  final DateTime createdDate;
  final DateTime? lastModifiedDate;
  final String? warehouseName;
  final String? stockTakeStatusCode;
  final String? stockTakeStatusName;
  final String? stockTakeStatusColor;
  final int? createdByUserId;
  final String? createdByName;
  final String scopeDisplay;
  final int varianceLineCount;
  final double netVarianceKg;
  final List<StockTakeItem> items;

  factory StockTakeDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = JsonReader.list(json, 'stockTakeItems') ?? const [];
    final itemsList = rawItems
        .whereType<Map<String, dynamic>>()
        .map((itemJson) => StockTakeItem.fromJson(itemJson))
        .toList();

    return StockTakeDetail(
      id: JsonReader.integer(json, 'id') ?? 0,
      warehouseId: JsonReader.integer(json, 'warehouseId') ?? 0,
      stockTakeStatusId: JsonReader.integer(json, 'stockTakeStatusId') ?? 0,
      stCode: JsonReader.string(json, 'stCode') ?? '',
      note: JsonReader.string(json, 'note'),
      startedDate: _parseDate(json, 'startedDate'),
      completedDate: _parseDate(json, 'completedDate'),
      approvedByUserId: JsonReader.integer(json, 'approvedByUserId'),
      approveNote: JsonReader.string(json, 'approveNote'),
      createdDate: _parseDate(json, 'createdDate') ?? DateTime.now(),
      lastModifiedDate: _parseDate(json, 'lastModifiedDate'),
      warehouseName: JsonReader.string(json, 'warehouseName'),
      stockTakeStatusCode: JsonReader.string(json, 'stockTakeStatusCode'),
      stockTakeStatusName: JsonReader.string(json, 'stockTakeStatusName'),
      stockTakeStatusColor: JsonReader.string(json, 'stockTakeStatusColor'),
      createdByUserId: JsonReader.integer(json, 'createdByUserId'),
      createdByName: JsonReader.string(json, 'createdByName'),
      scopeDisplay: JsonReader.string(json, 'scopeDisplay') ?? '',
      varianceLineCount: JsonReader.integer(json, 'varianceLineCount') ?? 0,
      netVarianceKg: JsonReader.decimal(json, 'netVarianceKg') ?? 0.0,
      items: itemsList,
    );
  }

  static DateTime? _parseDate(Map<String, dynamic> json, String key) {
    final val = JsonReader.string(json, key);
    return val != null ? DateTime.tryParse(val) : null;
  }
}

class StockTakeItem {
  const StockTakeItem({
    required this.id,
    required this.stockTakeId,
    this.productVariantId,
    this.locationId,
    this.paddyLotId,
    this.sku,
    this.productVariantName,
    required this.unitWeightKg,
    this.locationCode,
    this.zoneName,
    this.lotCode,
    required this.isQuarantine,
    required this.systemQuantity,
    this.actualQuantity,
    required this.difference,
    this.absoluteVarianceKg,
    this.variancePercent,
    required this.varianceSeverity,
    this.note,
    required this.qrScanned,
    required this.recountConfirmed,
    this.recountConfirmedBy,
    this.recountConfirmedAt,
  });

  final int id;
  final int stockTakeId;
  final int? productVariantId;
  final int? locationId;
  final int? paddyLotId;
  final String? sku;
  final String? productVariantName;
  final double unitWeightKg;
  final String? locationCode;
  final String? zoneName;
  final String? lotCode;
  final bool isQuarantine;
  final double systemQuantity;
  final double? actualQuantity;
  final double difference;
  final double? absoluteVarianceKg;
  final double? variancePercent;
  final String varianceSeverity;
  final String? note;
  final bool qrScanned;
  final bool recountConfirmed;
  final int? recountConfirmedBy;
  final DateTime? recountConfirmedAt;

  factory StockTakeItem.fromJson(Map<String, dynamic> json) {
    return StockTakeItem(
      id: JsonReader.integer(json, 'id') ?? 0,
      stockTakeId: JsonReader.integer(json, 'stockTakeId') ?? 0,
      productVariantId: JsonReader.integer(json, 'productVariantId'),
      locationId: JsonReader.integer(json, 'locationId'),
      paddyLotId: JsonReader.integer(json, 'paddyLotId'),
      sku: JsonReader.string(json, 'sku') ?? JsonReader.string(json, 'SKU'),
      productVariantName: JsonReader.string(json, 'productVariantName'),
      unitWeightKg: JsonReader.decimal(json, 'unitWeightKg') ?? 0.0,
      locationCode: JsonReader.string(json, 'locationCode'),
      zoneName: JsonReader.string(json, 'zoneName'),
      lotCode: JsonReader.string(json, 'lotCode'),
      isQuarantine: JsonReader.boolean(json, 'isQuarantine') ?? false,
      systemQuantity: JsonReader.decimal(json, 'systemQuantity') ?? 0.0,
      actualQuantity: JsonReader.decimal(json, 'actualQuantity'),
      difference: JsonReader.decimal(json, 'difference') ?? 0.0,
      absoluteVarianceKg: JsonReader.decimal(json, 'absoluteVarianceKg'),
      variancePercent: JsonReader.decimal(json, 'variancePercent'),
      varianceSeverity: JsonReader.string(json, 'varianceSeverity') ?? 'NONE',
      note: JsonReader.string(json, 'note'),
      qrScanned: JsonReader.boolean(json, 'qrScanned') ?? false,
      recountConfirmed: JsonReader.boolean(json, 'recountConfirmed') ?? false,
      recountConfirmedBy: JsonReader.integer(json, 'recountConfirmedBy'),
      recountConfirmedAt: _parseDate(json, 'recountConfirmedAt'),
    );
  }

  static DateTime? _parseDate(Map<String, dynamic> json, String key) {
    final val = JsonReader.string(json, key);
    return val != null ? DateTime.tryParse(val) : null;
  }
}

class StockTakePage {
  const StockTakePage({
    required this.items,
    required this.recordsTotal,
    required this.recordsFiltered,
  });

  final List<StockTakeSummary> items;
  final int recordsTotal;
  final int recordsFiltered;
}
