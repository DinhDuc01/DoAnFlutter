import '../models/weight_reading.dart';

/// Quyết định "khi nào tự nhận số cân" — tách khỏi UI để test được thuần.
///
/// Luật:
/// * Số cân phải ở trạng thái ỔN ĐỊNH liên tục đủ [stableWindow] mới nhận.
/// * Chỉ nhận MỘT lần cho mỗi lần đặt hàng lên cân: sau khi nhận, bộ đếm bị
///   "khoá" (`_armed = false`) cho tới khi cân rung trở lại hoặc hàng được nhấc
///   ra (khối lượng tụt xuống dưới [minWeightKg]). Nhờ vậy đặt một bao lên cân
///   không sinh ra hàng loạt lần nhận trùng.
/// * Số quá nhẹ ([minWeightKg]) coi như cân trống, không nhận.
class ScaleAutoCapture {
  ScaleAutoCapture({
    this.stableWindow = const Duration(milliseconds: 1500),
    this.minWeightKg = 0.05,
  });

  /// Thời gian số cân phải đứng yên trước khi được nhận.
  final Duration stableWindow;

  /// Dưới ngưỡng này coi như cân trống (chưa đặt hàng lên).
  final double minWeightKg;

  DateTime? _stableSince;
  bool _armed = true;

  /// Đang chờ đủ [stableWindow] để nhận số (dùng cho hiệu ứng đếm trên UI).
  bool get isArming => _armed && _stableSince != null;

  /// Tỉ lệ 0..1 của quá trình chờ ổn định tại thời điểm [now].
  double progressAt(DateTime now) {
    final since = _stableSince;
    if (!_armed || since == null) return 0;
    final elapsed = now.difference(since).inMilliseconds;
    final total = stableWindow.inMilliseconds;
    if (total <= 0) return 1;
    final ratio = elapsed / total;
    if (ratio <= 0) return 0;
    return ratio >= 1 ? 1 : ratio;
  }

  /// Nạp một mẫu cân. Trả về khối lượng cần nhận, hoặc null nếu chưa tới lúc.
  double? offer(WeightReading? reading, DateTime now) {
    if (reading == null ||
        !reading.isStable ||
        reading.weight < minWeightKg) {
      // Cân rung hoặc trống → mở khoá cho lần cân kế tiếp.
      _stableSince = null;
      _armed = true;
      return null;
    }

    if (!_armed) return null;

    _stableSince ??= now;
    if (now.difference(_stableSince!) < stableWindow) return null;

    _armed = false;
    _stableSince = null;
    return reading.weight;
  }

  /// Bỏ qua lần cân hiện tại (ví dụ người dùng bấm Hoàn tác) mà không nhận lại
  /// ngay số đang đứng yên trên cân.
  void suppressCurrent() {
    _armed = false;
    _stableSince = null;
  }

  void reset() {
    _stableSince = null;
    _armed = true;
  }
}
