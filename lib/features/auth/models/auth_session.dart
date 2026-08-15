import 'auth_permission.dart';

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

  /// Kiểm tra tài khoản có vai trò Admin hay không.
  bool get isAdmin => user.isAdmin;

  /// Kiểm tra tài khoản có một mã Vai trò cụ thể hay không (VD: 'ADMIN', 'AUDITOR').
  bool hasRole(String roleCode) => user.hasRole(roleCode);

  /// Kiểm tra người dùng có quyền thực hiện thao tác (action) trên Menu hay không.
  /// Nếu là ADMIN ➔ Mặc định có tất cả quyền.
  bool hasPermission(String menuCode, String action) =>
      user.hasPermission(menuCode, action);

  /// Kiểm tra người dùng có quyền xem/truy cập Menu hay không (quyền READ hoặc có menu trong danh sách).
  bool hasMenuAccess(String menuCode) => user.hasMenuAccess(menuCode);

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
    this.roles = const [],
    this.permissions = const [],
    this.menus = const [],
  });

  /// ID duy nhất của người dùng.
  final int id;

  /// Họ và tên đầy đủ của người dùng.
  final String fullName;

  /// Địa chỉ email đăng ký/đăng nhập của người dùng.
  final String email;

  /// Đường dẫn ảnh đại diện (avatar) của người dùng (nếu có).
  final String? avatarUrl;

  /// Danh sách các vai trò (roles) gán cho người dùng.
  final List<UserRole> roles;

  /// Danh sách quyền hạn (permissions) trên từng menu.
  final List<UserPermission> permissions;

  /// Danh sách các menu chức năng người dùng được phép truy cập.
  final List<UserMenu> menus;

  /// Kiểm tra tài khoản có vai trò ADMIN hay không.
  bool get isAdmin {
    return roles.any((r) => r.code == 'ADMIN' || r.code == '1001') ||
        permissions.isEmpty; // Nếu backend không trả permissions (super admin)
  }

  /// Kiểm tra có một vai trò cụ thể hay không.
  bool hasRole(String roleCode) {
    final code = roleCode.trim().toUpperCase();
    if (code == 'ADMIN' && isAdmin) return true;
    return roles.any((r) => r.code == code);
  }

  /// Kiểm tra có quyền hạn `action` trên `menuCode` hay không (VD: `hasPermission('STOCKTAKE', 'CREATE')`).
  bool hasPermission(String menuCode, String action) {
    if (isAdmin) return true;
    final targetMenu = menuCode.trim().toUpperCase();
    final targetAction = action.trim().toUpperCase();

    final perm = permissions.firstWhere(
      (p) => p.menuCode == targetMenu,
      orElse: () => const UserPermission(menuId: 0, menuCode: '', actions: {}),
    );
    return perm.hasAction(targetAction);
  }

  /// Kiểm tra người dùng có thể mở/xem Menu chức năng hay không.
  bool hasMenuAccess(String menuCode) {
    if (isAdmin) return true;
    final targetMenu = menuCode.trim().toUpperCase();

    // 1. Kiểm tra trong danh sách menus được cấp
    if (menus.any((m) => m.code == targetMenu)) return true;

    // 2. Kiểm tra trong danh sách permissions có quyền READ hoặc bất kỳ quyền nào
    final perm = permissions.firstWhere(
      (p) => p.menuCode == targetMenu,
      orElse: () => const UserPermission(menuId: 0, menuCode: '', actions: {}),
    );
    return perm.actions.isNotEmpty;
  }

  /// Tạo bản sao với một số trường được cập nhật.
  AuthUser copyWith({
    String? fullName,
    String? avatarUrl,
    List<UserRole>? roles,
    List<UserPermission>? permissions,
    List<UserMenu>? menus,
  }) {
    return AuthUser(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      menus: menus ?? this.menus,
    );
  }

  /// Chuyển thông tin người dùng sang Map để lưu cục bộ.
  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'avatarUrl': avatarUrl,
        'roles': roles.map((r) => r.toJson()).toList(),
        'permissions': permissions.map((p) => p.toJson()).toList(),
        'menus': menus.map((m) => m.toJson()).toList(),
      };

  /// Khôi phục thông tin người dùng từ dữ liệu đã lưu.
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'] ?? json['userRoles'];
    final rawPermissions = json['permissions'];
    final rawMenus = json['menus'];

    return AuthUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      roles: rawRoles is List
          ? rawRoles
              .map((r) => UserRole.fromJson((r as Map).cast<String, dynamic>()))
              .toList()
          : const [],
      permissions: rawPermissions is List
          ? rawPermissions
              .map((p) =>
                  UserPermission.fromJson((p as Map).cast<String, dynamic>()))
              .toList()
          : const [],
      menus: rawMenus is List
          ? rawMenus
              .map((m) => UserMenu.fromJson((m as Map).cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }
}
