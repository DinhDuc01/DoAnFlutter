/// Đại diện cho Vai trò (Role) của người dùng trong hệ thống (VD: ADMIN, WAREHOUSE_MANAGER).
class UserRole {
  const UserRole({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
      };

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: (json['code'] as String? ?? json['name'] as String? ?? '').trim().toUpperCase(),
      name: json['name'] as String? ?? json['code'] as String? ?? '',
    );
  }
}

/// Đại diện cho Quyền hạn (Permission) trên từng Menu / Chức năng.
class UserPermission {
  const UserPermission({
    required this.menuId,
    required this.menuCode,
    required this.actions,
  });

  final int menuId;
  final String menuCode;
  final Set<String> actions;

  bool hasAction(String action) {
    return actions.contains(action.trim().toUpperCase());
  }

  Map<String, dynamic> toJson() => {
        'menuId': menuId,
        'menuCode': menuCode,
        'actions': actions.toList(),
      };

  factory UserPermission.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'] ?? json['actionIds'] ?? json['actionCodes'];
    final actionSet = <String>{};
    if (rawActions is List) {
      for (final item in rawActions) {
        final parsed = _parseAction(item);
        if (parsed != null && parsed.isNotEmpty) {
          actionSet.add(parsed);
        }
      }
    }
    return UserPermission(
      menuId: (json['menuId'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt() ?? 0,
      menuCode: (json['menuCode'] as String? ?? json['code'] as String? ?? '').trim().toUpperCase(),
      actions: actionSet,
    );
  }

  static String? _parseAction(dynamic item) {
    if (item == null) return null;
    if (item is num) {
      return switch (item.toInt()) {
        1001 => 'CREATE',
        1002 => 'READ',
        1003 => 'UPDATE',
        1004 => 'DELETE',
        1005 => 'EXPORT',
        1006 => 'APPROVE',
        _ => item.toString(),
      };
    }
    final str = item.toString().trim().toUpperCase();
    return switch (str) {
      '1001' => 'CREATE',
      '1002' => 'READ',
      '1003' => 'UPDATE',
      '1004' => 'DELETE',
      '1005' => 'EXPORT',
      '1006' => 'APPROVE',
      _ => str,
    };
  }
}

/// Đại diện cho Menu / Chức năng được cấp quyền truy cập.
class UserMenu {
  const UserMenu({
    required this.id,
    required this.code,
    required this.name,
    this.path,
  });

  final int id;
  final String code;
  final String name;
  final String? path;

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'path': path,
      };

  factory UserMenu.fromJson(Map<String, dynamic> json) {
    return UserMenu(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: (json['code'] as String? ?? '').trim().toUpperCase(),
      name: json['name'] as String? ?? '',
      path: json['path'] as String?,
    );
  }
}
