import '../../../core/api/json_reader.dart';

class ResolvedQr {
  const ResolvedQr({
    required this.entityType,
    required this.entityId,
    required this.qrCode,
    required this.displayCode,
    this.lotType,
    this.productVariantId,
    this.productName,
    this.sku,
    this.riceVarietyName,
    this.statusName,
    this.remainingWeightKg,
    this.isQuarantined,
    this.zoneName,
    this.shelfRow,
    this.shelfLevel,
    this.slotCode,
    this.freeCapacityKg,
    this.warehouseName,
    this.navigationType,
  });

  final String entityType;
  final int entityId;
  final String qrCode;
  final String displayCode;
  final String? lotType;
  final int? productVariantId;
  final String? productName;
  final String? sku;
  final String? riceVarietyName;
  final String? statusName;
  final double? remainingWeightKg;
  final bool? isQuarantined;
  final String? zoneName;
  final String? shelfRow;
  final String? shelfLevel;
  final String? slotCode;
  final double? freeCapacityKg;
  final String? warehouseName;
  final String? navigationType;

  bool get isLot => entityType.toUpperCase().contains('LOT');

  String get title => productName ?? displayCode;

  String get subtitle {
    final values = [sku, riceVarietyName, warehouseName]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();
    return values.isEmpty ? entityType : values.join(' - ');
  }

  factory ResolvedQr.fromJson(Map<String, dynamic> json) {
    final product = JsonReader.map(json, 'productVariant');
    final riceVariety = JsonReader.map(json, 'riceVariety');
    final status = JsonReader.map(json, 'status');
    final warehouse = JsonReader.map(json, 'warehouse');
    final navigation = JsonReader.map(json, 'navigationTarget');
    return ResolvedQr(
      entityType: JsonReader.string(json, 'entityType') ?? 'UNKNOWN',
      entityId: JsonReader.integer(json, 'entityId') ?? 0,
      qrCode: JsonReader.string(json, 'qrCode') ?? '',
      displayCode: JsonReader.string(json, 'displayCode') ?? '',
      lotType: JsonReader.string(json, 'lotType'),
      productVariantId:
          product == null ? null : JsonReader.integer(product, 'id'),
      productName: product == null ? null : JsonReader.string(product, 'name'),
      sku: product == null ? null : JsonReader.string(product, 'sku'),
      riceVarietyName:
          riceVariety == null ? null : JsonReader.string(riceVariety, 'name'),
      statusName: status == null ? null : JsonReader.string(status, 'name'),
      remainingWeightKg: JsonReader.decimal(json, 'remainingWeightKg'),
      isQuarantined: JsonReader.boolean(json, 'isQuarantined'),
      zoneName: JsonReader.string(json, 'zoneName'),
      shelfRow: JsonReader.string(json, 'shelfRow'),
      shelfLevel: JsonReader.string(json, 'shelfLevel'),
      slotCode: JsonReader.string(json, 'slotCode'),
      freeCapacityKg: JsonReader.decimal(json, 'freeCapacityKg'),
      warehouseName:
          warehouse == null ? null : JsonReader.string(warehouse, 'name'),
      navigationType:
          navigation == null ? null : JsonReader.string(navigation, 'type'),
    );
  }
}
