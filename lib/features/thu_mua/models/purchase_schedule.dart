import '../../../core/api/json_reader.dart';

/// A paddy purchase appointment returned by the backend.
class PurchaseSchedule {
  const PurchaseSchedule({
    required this.id,
    required this.farmerId,
    this.riceVarietyId,
    this.warehouseId,
    this.warehouseName,
    this.statusId,
    required this.code,
    required this.farmerName,
    required this.status,
    required this.riceVariety,
    required this.scheduledAt,
    required this.estimatedWeightKg,
    required this.location,
    this.farmerPhone,
    this.farmerAddress,
    this.expectedPrice,
    this.note,
  });

  factory PurchaseSchedule.fromJson(Map<String, dynamic> json) {
    return PurchaseSchedule(
      id: JsonReader.integer(json, 'id') ?? 0,
      farmerId: JsonReader.integer(json, 'farmerId') ?? 0,
      riceVarietyId: JsonReader.integer(json, 'riceVarietyId'),
      warehouseId: JsonReader.integer(json, 'warehouseId'),
      warehouseName: JsonReader.string(json, 'warehouseName'),
      statusId: JsonReader.integer(json, 'statusId'),
      code: JsonReader.string(json, 'scheduleCode') ??
          JsonReader.string(json, 'code') ??
          '',
      farmerName: JsonReader.string(json, 'farmerName') ?? 'Nông hộ',
      status: JsonReader.string(json, 'statusName') ??
          JsonReader.string(json, 'status') ??
          'Chưa xác định',
      riceVariety:
          JsonReader.string(json, 'riceVarietyName') ?? 'Chưa rõ giống',
      scheduledAt: DateTime.tryParse(
            JsonReader.string(json, 'scheduleDate') ??
                JsonReader.string(json, 'scheduledAt') ??
                JsonReader.string(json, 'date') ??
                '',
          ) ??
          DateTime.now(),
      estimatedWeightKg: JsonReader.decimal(json, 'estimatedQtyKg') ??
          JsonReader.decimal(json, 'estimatedWeightKg') ??
          JsonReader.decimal(json, 'quantityKg') ??
          0,
      location: JsonReader.string(json, 'location') ?? 'Chưa có địa điểm',
      expectedPrice: JsonReader.decimal(json, 'expectedPrice'),
      note: JsonReader.string(json, 'note'),
    );
  }

  final int id;
  final int farmerId;
  final int? riceVarietyId;
  final int? warehouseId;
  final String? warehouseName;
  final int? statusId;
  final String code;
  final String farmerName;
  final String status;
  final String riceVariety;
  final DateTime scheduledAt;
  final double estimatedWeightKg;
  final String location;
  final String? farmerPhone;
  final String? farmerAddress;
  final double? expectedPrice;
  final String? note;

  bool get isCancelled => statusId == 6 || status.toLowerCase().contains('hủy');

  bool get canCreateReceipt {
    final normalized = status.toLowerCase();
    return !isCancelled &&
        statusId != 5 &&
        !normalized.contains('đã nhập kho') &&
        !normalized.contains('stocked');
  }

  PurchaseSchedule copyWith({
    String? farmerName,
    String? farmerPhone,
    String? farmerAddress,
  }) {
    return PurchaseSchedule(
      id: id,
      farmerId: farmerId,
      riceVarietyId: riceVarietyId,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      statusId: statusId,
      code: code,
      farmerName: farmerName ?? this.farmerName,
      status: status,
      riceVariety: riceVariety,
      scheduledAt: scheduledAt,
      estimatedWeightKg: estimatedWeightKg,
      location: location,
      farmerPhone: farmerPhone ?? this.farmerPhone,
      farmerAddress: farmerAddress ?? this.farmerAddress,
      expectedPrice: expectedPrice,
      note: note,
    );
  }
}
