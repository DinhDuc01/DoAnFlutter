import '../models/auth_session.dart';

/// Giao diện (Interface) trừu tượng định nghĩa các nghiệp vụ liên quan đến xác thực người dùng.
abstract class AuthService {
  /// Phương thức đăng nhập bằng email và mật khẩu.
  /// Trả về một đối tượng [AuthSession] chứa thông tin phiên đăng nhập của người dùng.
  Future<AuthSession> login({
    required String email,
    required String password,
  });
}

/// Lớp ngoại lệ (Exception) tùy chỉnh dùng để biểu diễn các lỗi xảy ra trong quá trình xác thực.
class AuthException implements Exception {
  const AuthException(this.message);

  /// Thông điệp lỗi chi tiết (ví dụ: "Sai mật khẩu", "Tài khoản không tồn tại").
  final String message;

  @override
  String toString() => message;
}
