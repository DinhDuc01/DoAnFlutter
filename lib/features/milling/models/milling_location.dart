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
    this.priority,
    this.isOutboundStaging = false,
    this.isLockedForOutbound = false,
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
  final int? priority;
  final bool isOutboundStaging;
  final bool isLockedForOutbound;
  final bool isQuarantine;
  final bool isActive;

  factory MillingLocation.fromJson(Map<String, dynamic> json) {
    return MillingLocation(
      id: JsonReader.integer(json, 'id') ??
          JsonReader.integer(json, 'Id') ??
          JsonReader.integer(json, 'locationId') ??
          JsonReader.integer(json, 'LocationId') ??
          0,
      warehouseId: JsonReader.integer(json, 'warehouseId') ??
          JsonReader.integer(json, 'WarehouseId') ??
          0,
      warehouseName: JsonReader.string(json, 'warehouseName') ??
          JsonReader.string(json, 'WarehouseName') ??
          '',
      slotCode: JsonReader.string(json, 'slotCode') ??
          JsonReader.string(json, 'SlotCode') ??
          JsonReader.string(json, 'locationCode') ??
          JsonReader.string(json, 'LocationCode') ??
          JsonReader.string(json, 'code') ??
          JsonReader.string(json, 'Code') ??
          '',
      zoneName: JsonReader.string(json, 'zoneName') ??
          JsonReader.string(json, 'ZoneName') ??
          '',
      maxCapacity: JsonReader.decimal(json, 'maxCapacity') ??
          JsonReader.decimal(json, 'MaxCapacity'),
      currentOccupancy: JsonReader.decimal(json, 'currentOccupancy') ??
          JsonReader.decimal(json, 'CurrentOccupancy') ??
          0,
      allowedCategoryId: JsonReader.integer(json, 'allowedCategoryId') ??
          JsonReader.integer(json, 'AllowedCategoryId'),
      currentProductVariantId:
          JsonReader.integer(json, 'currentProductVariantId') ??
              JsonReader.integer(json, 'CurrentProductVariantId'),
      priority: JsonReader.integer(json, 'priority') ??
          JsonReader.integer(json, 'Priority'),
      isOutboundStaging: JsonReader.boolean(json, 'isOutboundStaging') ??
          JsonReader.boolean(json, 'IsOutboundStaging') ??
          false,
      isLockedForOutbound: JsonReader.boolean(json, 'isLockedForOutbound') ??
          JsonReader.boolean(json, 'IsLockedForOutbound') ??
          false,
      isQuarantine: JsonReader.boolean(json, 'isQuarantine') ??
          JsonReader.boolean(json, 'IsQuarantine') ??
          false,
      isActive: JsonReader.boolean(json, 'isActive') ??
          JsonReader.boolean(json, 'IsActive') ??
          false,
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
      locationId: JsonReader.integer(json, 'locationId') ??
          JsonReader.integer(json, 'LocationId') ??
          JsonReader.integer(json, 'id') ??
          JsonReader.integer(json, 'Id') ??
          0,
      locationCode: JsonReader.string(json, 'locationCode') ??
          JsonReader.string(json, 'LocationCode') ??
          JsonReader.string(json, 'slotCode') ??
          JsonReader.string(json, 'SlotCode') ??
          JsonReader.string(json, 'code') ??
          JsonReader.string(json, 'Code') ??
          '',
      zoneName: JsonReader.string(json, 'zoneName') ??
          JsonReader.string(json, 'ZoneName') ??
          '',
      currentOccupancyKg: JsonReader.decimal(json, 'currentOccupancyKg') ??
          JsonReader.decimal(json, 'CurrentOccupancyKg') ??
          0,
      maxCapacityKg: JsonReader.decimal(json, 'maxCapacityKg') ??
          JsonReader.decimal(json, 'MaxCapacityKg') ??
          0,
      freeCapacityKg: JsonReader.decimal(json, 'freeCapacityKg') ??
          JsonReader.decimal(json, 'FreeCapacityKg') ??
          0,
      currentProductVariantId:
          JsonReader.integer(json, 'currentProductVariantId') ??
              JsonReader.integer(json, 'CurrentProductVariantId'),
      isEmpty: JsonReader.boolean(json, 'isEmpty') ??
          JsonReader.boolean(json, 'IsEmpty') ??
          false,
      reason: JsonReader.string(json, 'reason') ??
          JsonReader.string(json, 'Reason'),
    );
  }

  String get displayName => locationCode.trim().isNotEmpty
      ? '$locationCode${zoneName.trim().isEmpty ? '' : ' · $zoneName'}'
      : 'Vị trí #$locationId';
}
