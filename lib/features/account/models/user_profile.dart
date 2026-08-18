/// Hồ sơ cá nhân của người dùng đang đăng nhập (khớp GET /api/v1/user/me).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.gender,
    this.phoneNumber,
    this.addresDetail,
    this.avatarId,
    this.avatarUrl,
  });

  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;

  /// Giới tính: 1 = Nam, 0 = Nữ (khớp với web).
  final int? gender;
  final String? phoneNumber;

  /// Địa chỉ chi tiết (tên trường theo backend là `addresDetail`).
  final String? addresDetail;

  /// Id ảnh đại diện trong File Manager (gửi lại khi cập nhật hồ sơ).
  final int? avatarId;

  /// URL ảnh đại diện để hiển thị.
  final String? avatarUrl;

  String get fullName => '$firstName $lastName'.trim();

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    int? gender,
    String? phoneNumber,
    String? addresDetail,
    int? avatarId,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id,
      username: username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      addresDetail: addresDetail ?? this.addresDetail,
      avatarId: avatarId ?? this.avatarId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
