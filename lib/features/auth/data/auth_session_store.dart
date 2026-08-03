import '../models/auth_session.dart';

/// Kho lưu trữ phiên đăng nhập tạm thời trong bộ nhớ (Memory Store).
/// Giúp truy cập nhanh thông tin người dùng đang đăng nhập và Access Token từ bất kỳ đâu trong ứng dụng.
class AuthSessionStore {
  AuthSessionStore._(); // Hạn chế khởi tạo đối tượng trực tiếp

  /// Phiên đăng nhập hiện tại. Sẽ bằng null nếu người dùng chưa đăng nhập.
  static AuthSession? current;
}
