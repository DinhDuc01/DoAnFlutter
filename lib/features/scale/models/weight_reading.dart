import 'dart:convert';

/// A weight sample sent by the ESP32 scale over BLE.
class WeightReading {
  const WeightReading({
    required this.weight,
    required this.unit,
    required this.isStable,
    required this.receivedAt,
    this.deviceName,
  });

  final double weight;
  final String unit;
  final bool isStable;
  final DateTime receivedAt;

  /// Tên thiết bị cân đã đọc số này (gán khi màn cân trả kết quả về). Dùng để
  /// ghi lại `scaleDevice` trên phiếu — payload BLE không chứa thông tin này.
  final String? deviceName;

  /// True only when this sample is safe to apply to a weighing form.
  bool get canApplyToWeighing =>
      isStable &&
      unit.trim().toLowerCase() == 'kg' &&
      weight.isFinite &&
      weight > 0 &&
      isFresh();

  bool isFresh({DateTime? now, Duration maxAge = const Duration(seconds: 5)}) {
    final reference = now ?? DateTime.now();
    final age = reference.difference(receivedAt);
    return !age.isNegative && age <= maxAge;
  }

  WeightReading copyWith({String? deviceName}) => WeightReading(
        weight: weight,
        unit: unit,
        isStable: isStable,
        receivedAt: receivedAt,
        deviceName: deviceName ?? this.deviceName,
      );

  factory WeightReading.fromBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('Payload BLE trống.');
    }
    return WeightReading.fromJsonString(utf8.decode(bytes));
  }

  factory WeightReading.fromJsonString(String source) {
    final decoded = jsonDecode(source.trim());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Payload phải là một JSON object.');
    }

    final rawWeight = decoded['w'];
    final rawStable = decoded['s'];
    if (rawWeight is! num || rawStable is! bool) {
      throw const FormatException('Payload thiếu trường w hoặc s hợp lệ.');
    }

    final weight = rawWeight.toDouble();
    final unit = decoded['u'] is String ? decoded['u'] as String : 'kg';
    if (!weight.isFinite || weight <= 0) {
      throw const FormatException('Khối lượng phải hữu hạn và lớn hơn 0.');
    }
    if (unit.trim().toLowerCase() != 'kg') {
      throw const FormatException('Đơn vị cân phải là kg.');
    }

    return WeightReading(
      weight: weight,
      unit: unit,
      isStable: rawStable,
      receivedAt: DateTime.now(),
    );
  }
}
