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

  /// Route/list/detail access is stricter than menu visibility: the session
  /// must explicitly contain the READ action for the requested menu.
  bool hasReadAccess(String menuCode) => user.hasReadAccess(menuCode);

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
    return roles.any((r) => r.code == 'ADMIN' || r.code == '1001');
  }

  /// Mobile không phục vụ tài khoản quản trị hoặc kiểm toán.
  /// Backend có thể trả role dưới dạng `code` hoặc chỉ có `name`,
  /// vì vậy kiểm tra cả hai trường. OWNER/Chủ cơ sở không bị chặn.
  bool get isMobileBlocked {
    final roleCodes = roles.map((role) => role.code.trim().toUpperCase());
    final roleNames = roles.map((role) => role.name.trim().toUpperCase());
    final roleIds = roles.map((role) => role.id);
    final values = {...roleCodes, ...roleNames};

    return roleIds.contains(1001) ||
        values.contains('ADMIN') ||
        values.contains('QUẢN TRỊ VIÊN') ||
        values.contains('AUDITOR') ||
        values.contains('KIỂM TOÁN VIÊN');
  }

  /// Nhân viên kho dùng Mobile cho nghiệp vụ kho và xuất/giao hàng, nhưng
  /// Thu mua, Đơn bán và Chất lượng chỉ được xem. Đây là policy Mobile bổ
  /// sung, không thay thế authorization của Backend.
  bool get isWarehouseWorker {
    return roles.any((role) {
      final code = role.code.trim().toUpperCase();
      final name = role.name.trim().toUpperCase();
      return role.id == 1012 || code == 'WAREHOUSE' || name == 'NHÂN VIÊN KHO';
    });
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

  /// Returns true only when Backend granted READ for [menuCode].
  /// Having CREATE/UPDATE/DELETE alone must not open a feature route.
  bool hasReadAccess(String menuCode) => hasPermission(menuCode, 'READ');

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

    // `/auth/me/session` trả menu theo cây (ví dụ Bán hàng -> Đơn bán,
    // Trả hàng, Xuất kho). Permission chỉ mang menuId, nên phải làm phẳng cả
    // menu con để ánh xạ menuId -> menuCode. Nếu chỉ đọc cấp gốc, role SALES
    // vẫn đăng nhập được nhưng toàn bộ shortcut con sẽ bị ẩn.
    final parsedMenus =
        rawMenus is List ? _flattenMenus(rawMenus) : <UserMenu>[];
    final menuCodesById = <int, String>{
      for (final menu in parsedMenus)
        if (menu.id > 0 && menu.code.isNotEmpty) menu.id: menu.code,
    };
    final unmergedPermissions = rawPermissions is List
        ? rawPermissions.whereType<Map>().map((p) {
            final permission = UserPermission.fromJson(
              p.cast<String, dynamic>(),
            );
            final menuCode = permission.menuCode.isNotEmpty
                ? permission.menuCode
                : menuCodesById[permission.menuId] ?? '';
            return UserPermission(
              menuId: permission.menuId,
              menuCode: menuCode,
              actions: permission.actions,
            );
          }).toList()
        : <UserPermission>[];
    final parsedPermissions = _mergePermissions(unmergedPermissions);

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
      permissions: parsedPermissions,
      menus: parsedMenus,
    );
  }
}

List<UserPermission> _mergePermissions(List<UserPermission> permissions) {
  final merged = <UserPermission>[];

  for (final permission in permissions) {
    final code = permission.menuCode.trim().toUpperCase();
    final id = permission.menuId;
    // A permission with neither identity cannot authorize any feature.
    if (code.isEmpty && id <= 0) continue;

    final index = merged.indexWhere(
      (item) =>
          (code.isNotEmpty && item.menuCode == code) ||
          (id > 0 && item.menuId == id),
    );
    final existing = index < 0 ? null : merged[index];
    final combined = UserPermission(
      menuId: existing?.menuId ?? id,
      menuCode:
          existing?.menuCode.isNotEmpty == true ? existing!.menuCode : code,
      actions: <String>{
        ...?existing?.actions,
        ...permission.actions,
      },
    );
    if (index < 0) {
      merged.add(combined);
    } else {
      merged[index] = combined;
    }
  }

  return List<UserPermission>.unmodifiable(merged);
}

List<UserMenu> _flattenMenus(List<dynamic> rawMenus) {
  final result = <UserMenu>[];
  final seenIds = <int>{};

  void visit(dynamic raw) {
    if (raw is! Map) return;
    final json = raw.cast<String, dynamic>();
    final menu = UserMenu.fromJson(json);
    if (menu.id > 0 && seenIds.add(menu.id)) {
      result.add(menu);
    }

    final children = json['child'] ?? json['children'];
    if (children is List) {
      for (final child in children) {
        visit(child);
      }
    }
  }

  for (final menu in rawMenus) {
    visit(menu);
  }
  return result;
}
