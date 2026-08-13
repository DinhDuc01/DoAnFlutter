import 'dart:convert';

/// A weight sample sent by the ESP32 scale over BLE.
class WeightReading {
  const WeightReading({
    required this.weight,
    required this.unit,
    required this.isStable,
    required this.receivedAt,
  });

  final double weight;
  final String unit;
  final bool isStable;
  final DateTime receivedAt;

  bool isFresh({DateTime? now, Duration maxAge = const Duration(seconds: 5)}) {
    final reference = now ?? DateTime.now();
    final age = reference.difference(receivedAt);
    return !age.isNegative && age <= maxAge;
  }

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
    if (!weight.isFinite || weight <= 0) {
      throw const FormatException('Trọng lượng phải là số hữu hạn lớn hơn 0.');
    }

    final unit = decoded['u'] is String
        ? (decoded['u'] as String).trim().toLowerCase()
        : 'kg';
    if (unit != 'kg') {
      throw FormatException('Đơn vị cân không được hỗ trợ: $unit.');
    }

    return WeightReading(
      weight: weight,
      unit: unit,
      isStable: rawStable,
      receivedAt: DateTime.now(),
    );
  }
}
