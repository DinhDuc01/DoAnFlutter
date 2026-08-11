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

class PaddyLotTraceability {
  const PaddyLotTraceability({
    required this.requestedLotId,
    required this.requestedLotCode,
    required this.events,
    required this.isTruncated,
  });

  final int requestedLotId;
  final String requestedLotCode;
  final List<TraceabilityEvent> events;
  final bool isTruncated;

  factory PaddyLotTraceability.fromJson(Map<String, dynamic> json) {
    final timeline = JsonReader.list(json, 'timeline') ?? const [];
    return PaddyLotTraceability(
      requestedLotId: JsonReader.integer(json, 'requestedLotId') ?? 0,
      requestedLotCode: JsonReader.string(json, 'requestedLotCode') ?? '',
      isTruncated: JsonReader.boolean(json, 'isTruncated') ?? false,
      events: [
        for (final item in timeline)
          if (item is Map<String, dynamic>) TraceabilityEvent.fromJson(item),
      ],
    );
  }
}

DateTime? _date(Map<String, dynamic> json, String key) {
  final value = JsonReader.string(json, key);
  return value == null ? null : DateTime.tryParse(value)?.toLocal();
}
