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
    this.statusCode,
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
    this.receiptCount = 0,
    this.receiptedWeightKg = 0,
    this.remainingQtyKg,
    this.canCreateReceiptFlag,
  });

  factory PurchaseSchedule.fromJson(Map<String, dynamic> json) {
    return PurchaseSchedule(
      id: JsonReader.integer(json, 'id') ?? 0,
      farmerId: JsonReader.integer(json, 'farmerId') ?? 0,
      riceVarietyId: JsonReader.integer(json, 'riceVarietyId'),
      warehouseId: JsonReader.integer(json, 'warehouseId'),
      warehouseName: JsonReader.string(json, 'warehouseName'),
      statusId: JsonReader.integer(json, 'statusId'),
      statusCode: JsonReader.string(json, 'statusCode'),
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
      receiptCount: JsonReader.integer(json, 'receiptCount') ?? 0,
      receiptedWeightKg: JsonReader.decimal(json, 'receiptedWeightKg') ?? 0,
      remainingQtyKg: JsonReader.decimal(json, 'remainingQtyKg'),
      canCreateReceiptFlag: JsonReader.boolean(json, 'canCreateReceipt'),
    );
  }

  final int id;
  final int farmerId;
  final int? riceVarietyId;
  final int? warehouseId;
  final String? warehouseName;
  final int? statusId;
  final String? statusCode;
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

  /// Số phiếu mua lúa chưa xóa thuộc lịch này.
  final int receiptCount;

  /// Tổng khối lượng thực tế (kg) của các phiếu mua thuộc lịch này.
  final double receiptedWeightKg;

  /// Khối lượng còn lại có thể lập phiếu (null khi lịch không khai báo dự kiến).
  final double? remainingQtyKg;

  /// Cờ do backend tính sẵn — nguồn sự thật cho việc chặn tạo phiếu.
  final bool? canCreateReceiptFlag;

  bool get isCancelled =>
      statusCode?.toUpperCase() == 'CANCELLED' ||
      statusId == 6 ||
      status.toLowerCase().contains('hủy') ||
      status.toLowerCase().contains('huỷ');

  /// Lịch đã lập đủ phiếu theo khối lượng dự kiến chưa.
  /// Lịch không khai báo khối lượng dự kiến chỉ được 1 phiếu.
  bool get isFullyReceipted {
    if (estimatedWeightKg > 0) {
      return receiptedWeightKg >= estimatedWeightKg - 0.001;
    }
    return receiptCount > 0;
  }

  bool get _isBlockedByStatus {
    final code = statusCode?.toUpperCase();
    if (code != null && code.isNotEmpty) {
      return code == 'CANCELLED' ||
          code == 'STOCKED' ||
          code == 'PARTIALLY_STOCKED';
    }
    final normalized = status.toLowerCase();
    return isCancelled ||
        statusId == 5 ||
        normalized.contains('đã nhập kho') ||
        normalized.contains('nhập kho một phần') ||
        normalized.contains('stocked');
  }

  /// Lịch còn được lập thêm phiếu mua hay không.
  /// Ưu tiên cờ backend trả về; chỉ tự suy ra khi API cũ chưa có cờ này.
  bool get canCreateReceipt =>
      canCreateReceiptFlag ?? (!_isBlockedByStatus && !isFullyReceipted);

  /// Lý do không lập được phiếu — hiển thị trên nút để người dùng hiểu vì sao bị khóa.
  String get blockedReason {
    if (isCancelled) return 'Lịch đã hủy';
    if (_isBlockedByStatus) return 'Lịch đã nhập kho';
    if (isFullyReceipted) return 'Lịch đã đủ phiếu mua';
    return '';
  }

  PurchaseSchedule copyWith({
    String? farmerName,
    String? farmerPhone,
    String? farmerAddress,
    String? riceVariety,
    int? riceVarietyId,
    int? warehouseId,
    String? warehouseName,
    int? statusId,
    String? statusCode,
    String? status,
    double? estimatedWeightKg,
    String? location,
    double? expectedPrice,
    String? note,
    int? receiptCount,
    double? receiptedWeightKg,
    double? remainingQtyKg,
    bool? canCreateReceiptFlag,
  }) {
    return PurchaseSchedule(
      id: id,
      farmerId: farmerId,
      riceVarietyId: riceVarietyId ?? this.riceVarietyId,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      statusId: statusId ?? this.statusId,
      statusCode: statusCode ?? this.statusCode,
      code: code,
      farmerName: farmerName ?? this.farmerName,
      status: status ?? this.status,
      riceVariety: riceVariety ?? this.riceVariety,
      scheduledAt: scheduledAt,
      estimatedWeightKg: estimatedWeightKg ?? this.estimatedWeightKg,
      location: location ?? this.location,
      farmerPhone: farmerPhone ?? this.farmerPhone,
      farmerAddress: farmerAddress ?? this.farmerAddress,
      expectedPrice: expectedPrice ?? this.expectedPrice,
      note: note ?? this.note,
      receiptCount: receiptCount ?? this.receiptCount,
      receiptedWeightKg: receiptedWeightKg ?? this.receiptedWeightKg,
      remainingQtyKg: remainingQtyKg ?? this.remainingQtyKg,
      canCreateReceiptFlag: canCreateReceiptFlag ?? this.canCreateReceiptFlag,
    );
  }
}
