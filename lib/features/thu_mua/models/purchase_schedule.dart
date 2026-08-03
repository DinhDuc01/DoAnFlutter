import '../../../core/api/json_reader.dart';

/// A paddy purchase appointment returned by the backend.
class PurchaseSchedule {
  const PurchaseSchedule({
    required this.id,
    required this.farmerId,
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
      code: JsonReader.string(json, 'scheduleCode') ?? '',
      farmerName: JsonReader.string(json, 'farmerName') ?? 'Nông hộ',
      status: JsonReader.string(json, 'statusName') ?? 'Chưa xác định',
      riceVariety:
          JsonReader.string(json, 'riceVarietyName') ?? 'Chưa rõ giống',
      scheduledAt: DateTime.tryParse(
            JsonReader.string(json, 'scheduleDate') ?? '',
          ) ??
          DateTime.now(),
      estimatedWeightKg: JsonReader.decimal(json, 'estimatedQtyKg') ?? 0,
      location: JsonReader.string(json, 'location') ?? 'Chưa có địa điểm',
      expectedPrice: JsonReader.decimal(json, 'expectedPrice'),
      note: JsonReader.string(json, 'note'),
    );
  }

  final int id;
  final int farmerId;
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

  bool get isCancelled => status.toLowerCase().contains('hủy');

  PurchaseSchedule copyWith({
    String? farmerName,
    String? farmerPhone,
    String? farmerAddress,
  }) {
    return PurchaseSchedule(
      id: id,
      farmerId: farmerId,
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
