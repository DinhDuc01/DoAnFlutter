import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';

/// Kho lưu trữ phiên đăng nhập.
///
/// Vừa giữ phiên trong bộ nhớ (RAM) để truy cập nhanh Access Token từ bất kỳ đâu,
/// vừa lưu xuống bộ nhớ cục bộ (SharedPreferences) để lần mở app sau không phải
/// đăng nhập lại.
class AuthSessionStore {
  AuthSessionStore._(); // Hạn chế khởi tạo đối tượng trực tiếp

  /// Khoá lưu phiên trong SharedPreferences.
  static const String _storageKey = 'auth_session';

  /// Phiên đăng nhập hiện tại. Sẽ bằng null nếu người dùng chưa đăng nhập.
  static AuthSession? current;

  /// Nạp lại phiên đã lưu (nếu có) khi khởi động app. Gọi 1 lần trong `main()`.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final session = AuthSession.fromJson(decoded);
        // Chỉ khôi phục khi còn đủ token hợp lệ.
        if (session.accessToken.isNotEmpty) current = session;
      }
    } catch (_) {
      current = null;
    }
  }

  /// Lưu phiên vào RAM + bộ nhớ cục bộ sau khi đăng nhập thành công.
  static Future<void> save(AuthSession session) async {
    // Gán RAM trước để request kế tiếp dùng ngay token mới. Việc lưu local có
    // thể thất bại nhưng không nên làm hỏng phiên đang chạy hiện tại.
    current = session;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(session.toJson()));
    } catch (_) {
      // Bỏ qua lỗi ghi cục bộ — phiên vẫn dùng được trong phiên chạy hiện tại.
    }
  }

  /// Cập nhật cặp token mới sau khi làm mới (refresh) và lưu lại cục bộ.
  static Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final existing = current;
    if (existing == null) return;
    await save(existing.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
    ));
  }

  /// Xoá phiên khỏi RAM + bộ nhớ cục bộ khi đăng xuất.
  static Future<void> clear() async {
    // Xóa RAM trước để UI/route không tiếp tục đọc permission cũ trong lúc
    // SharedPreferences đang được cập nhật bất đồng bộ.
    current = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Bỏ qua lỗi xoá cục bộ.
    }
  }
}
