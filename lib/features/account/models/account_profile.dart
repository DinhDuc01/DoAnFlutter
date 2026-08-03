/// Lớp dữ liệu chứa thông tin chi tiết về hồ sơ cá nhân và cấu hình cài đặt của người dùng.
class AccountProfile {
  const AccountProfile({
    required this.name,
    required this.email,
    required this.role,
    required this.avatarInitial,
    required this.inboundCount,
    required this.outboundCount,
    required this.inventoryCount,
    required this.assignedWarehouse,
    required this.notificationsEnabled,
    required this.darkModeEnabled,
    required this.language,
  });

  /// Họ tên hiển thị
  final String name;

  /// Địa chỉ email
  final String email;

  /// Vai trò/Chức vụ (ví dụ: Nhân viên kho, Quản lý)
  final String role;

  /// Chữ cái đầu của tên (để vẽ avatar tạm thời)
  final String avatarInitial;

  /// Số phiếu nhập kho đã thực hiện
  final int inboundCount;

  /// Số phiếu xuất kho đã thực hiện
  final int outboundCount;

  /// Số phiếu kiểm kê đã thực hiện.
  final int inventoryCount;

  /// Tên kho hàng được phân công phụ trách
  final String assignedWarehouse;

  /// Cài đặt bật/tắt nhận thông báo từ hệ thống
  final bool notificationsEnabled;

  /// Cài đặt chế độ tối (Dark mode)
  final bool darkModeEnabled;

  /// Ngôn ngữ giao diện (ví dụ: Tiếng Việt, Tiếng Anh)
  final String language;

  /// Tạo bản sao mới của [AccountProfile] và cập nhật một số trường cụ thể.
  AccountProfile copyWith({
    bool? notificationsEnabled,
    bool? darkModeEnabled,
  }) {
    return AccountProfile(
      name: name,
      email: email,
      role: role,
      avatarInitial: avatarInitial,
      inboundCount: inboundCount,
      outboundCount: outboundCount,
      inventoryCount: inventoryCount,
      assignedWarehouse: assignedWarehouse,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      language: language,
    );
  }
}
