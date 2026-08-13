import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tuỳ chọn của người dùng cho cân điện tử (lưu cục bộ, không đụng backend).
///
/// Hiện chỉ có một cờ: tự nhận số khi cân báo ổn định. Mặc định BẬT vì đây là
/// bước cắt được nhiều thao tác nhất — đặt bao lên cân là số tự vào ô, không
/// phải chạm màn hình. Người dùng có thể tắt ngay trên thanh cân.
class ScalePreferences extends ChangeNotifier {
  ScalePreferences._();

  static final ScalePreferences instance = ScalePreferences._();

  static const _autoCaptureKey = 'scale.auto_capture_enabled';

  bool _autoCapture = true;
  bool _loaded = false;

  bool get autoCapture => _autoCapture;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoCapture = prefs.getBool(_autoCaptureKey) ?? true;
    } catch (_) {
      _autoCapture = true; // Không đọc được prefs thì giữ mặc định.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setAutoCapture(bool value) async {
    if (_autoCapture == value) return;
    _autoCapture = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoCaptureKey, value);
    } catch (_) {
      // Lưu hỏng thì vẫn giữ lựa chọn trong phiên hiện tại.
    }
  }

  @visibleForTesting
  void debugReset({bool autoCapture = true}) {
    _autoCapture = autoCapture;
    _loaded = false;
  }
}
