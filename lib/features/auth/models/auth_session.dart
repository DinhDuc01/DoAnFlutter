/// Đại diện cho phiên đăng nhập (session) của người dùng sau khi xác thực thành công.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  /// Token truy cập dùng để xác thực các request gửi lên API.
  final String accessToken;

  /// Token làm mới dùng để lấy accessToken mới khi accessToken cũ hết hạn.
  final String refreshToken;

  /// Thông tin chi tiết của người dùng đăng nhập.
  final AuthUser user;
}

/// Đại diện cho thông tin người dùng được trả về từ phiên đăng nhập.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
  });

  /// ID duy nhất của người dùng.
  final int id;

  /// Họ và tên đầy đủ của người dùng.
  final String fullName;

  /// Địa chỉ email đăng ký/đăng nhập của người dùng.
  final String email;

  /// Đường dẫn ảnh đại diện (avatar) của người dùng (nếu có).
  final String? avatarUrl;
}
