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

  /// Tạo bản sao phiên với cặp token mới (dùng sau khi làm mới token)
  /// hoặc thông tin người dùng mới (dùng sau khi cập nhật hồ sơ).
  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    AuthUser? user,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
    );
  }

  /// Chuyển phiên sang Map để lưu vào bộ nhớ cục bộ (SharedPreferences).
  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'user': user.toJson(),
      };

  /// Khôi phục phiên từ dữ liệu đã lưu trong bộ nhớ cục bộ.
  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['accessToken'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
        user: AuthUser.fromJson(
          (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
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

  /// Tạo bản sao với một số trường được cập nhật (dùng sau khi sửa hồ sơ).
  AuthUser copyWith({String? fullName, String? avatarUrl}) {
    return AuthUser(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  /// Chuyển thông tin người dùng sang Map để lưu cục bộ.
  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'avatarUrl': avatarUrl,
      };

  /// Khôi phục thông tin người dùng từ dữ liệu đã lưu.
  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: (json['id'] as num?)?.toInt() ?? 0,
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
      );
}
