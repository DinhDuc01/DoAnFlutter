import '../../../core/api/json_reader.dart';

class MillingLocation {
  const MillingLocation({
    required this.id,
    required this.warehouseId,
    required this.warehouseName,
    required this.slotCode,
    required this.zoneName,
    required this.maxCapacity,
    required this.currentOccupancy,
    this.allowedCategoryId,
    this.currentProductVariantId,
    required this.isQuarantine,
    required this.isActive,
  });

  final int id;
  final int warehouseId;
  final String warehouseName;
  final String slotCode;
  final String zoneName;
  final double? maxCapacity;
  final double currentOccupancy;
  final int? allowedCategoryId;
  final int? currentProductVariantId;
  final bool isQuarantine;
  final bool isActive;

  factory MillingLocation.fromJson(Map<String, dynamic> json) {
    return MillingLocation(
      id: JsonReader.integer(json, 'id') ?? 0,
      warehouseId: JsonReader.integer(json, 'warehouseId') ?? 0,
      warehouseName: JsonReader.string(json, 'warehouseName') ?? '',
      slotCode: JsonReader.string(json, 'slotCode') ?? '',
      zoneName: JsonReader.string(json, 'zoneName') ?? '',
      maxCapacity: JsonReader.decimal(json, 'maxCapacity'),
      currentOccupancy: JsonReader.decimal(json, 'currentOccupancy') ?? 0,
      allowedCategoryId: JsonReader.integer(json, 'allowedCategoryId'),
      currentProductVariantId:
          JsonReader.integer(json, 'currentProductVariantId'),
      isQuarantine: JsonReader.boolean(json, 'isQuarantine') ?? false,
      isActive: JsonReader.boolean(json, 'isActive') ?? false,
    );
  }

  String get displayName => slotCode.trim().isNotEmpty
      ? '$slotCode${zoneName.trim().isEmpty ? '' : ' · $zoneName'}'
      : (zoneName.trim().isEmpty ? 'Vị trí #$id' : zoneName);
}

class MillingPutawaySuggestion {
  const MillingPutawaySuggestion({
    required this.locationId,
    required this.locationCode,
    required this.zoneName,
    required this.currentOccupancyKg,
    required this.maxCapacityKg,
    required this.freeCapacityKg,
    this.currentProductVariantId,
    required this.isEmpty,
    this.reason,
  });

  final int locationId;
  final String locationCode;
  final String zoneName;
  final double currentOccupancyKg;
  final double maxCapacityKg;
  final double freeCapacityKg;
  final int? currentProductVariantId;
  final bool isEmpty;
  final String? reason;

  factory MillingPutawaySuggestion.fromJson(Map<String, dynamic> json) {
    return MillingPutawaySuggestion(
      locationId: JsonReader.integer(json, 'locationId') ?? 0,
      locationCode: JsonReader.string(json, 'locationCode') ?? '',
      zoneName: JsonReader.string(json, 'zoneName') ?? '',
      currentOccupancyKg:
          JsonReader.decimal(json, 'currentOccupancyKg') ?? 0,
      maxCapacityKg: JsonReader.decimal(json, 'maxCapacityKg') ?? 0,
      freeCapacityKg: JsonReader.decimal(json, 'freeCapacityKg') ?? 0,
      currentProductVariantId:
          JsonReader.integer(json, 'currentProductVariantId'),
      isEmpty: JsonReader.boolean(json, 'isEmpty') ?? false,
      reason: JsonReader.string(json, 'reason'),
    );
  }

  String get displayName => locationCode.trim().isNotEmpty
      ? '$locationCode${zoneName.trim().isEmpty ? '' : ' · $zoneName'}'
      : 'Vị trí #$locationId';
}
