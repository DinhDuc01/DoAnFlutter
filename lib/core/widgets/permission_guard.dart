import 'package:flutter/material.dart';

import '../../features/auth/data/auth_session_store.dart';
import '../../features/auth/models/auth_session.dart';
import '../screens/permission_denied_screen.dart';

/// Widget dựng UI dựa trên Quyền hạn của người dùng.
///
/// Ví dụ:
/// ```dart
/// PermissionBuilder(
///   menuCode: 'STOCKTAKE',
///   action: 'CREATE',
///   builder: (context, hasPermission) => FloatingActionButton(...),
/// )
/// ```
class PermissionBuilder extends StatelessWidget {
  const PermissionBuilder({
    required this.menuCode,
    this.action,
    this.session,
    this.builder,
    this.child,
    this.fallback = const SizedBox.shrink(),
    super.key,
  });

  /// Mã Menu cần kiểm tra (VD: 'STOCKTAKE', 'MILLING_ORDERS').
  final String menuCode;

  /// Mã Thao tác cần kiểm tra (VD: 'CREATE', 'UPDATE', 'APPROVE', 'READ').
  /// Nếu null ➔ Kiểm tra quyền truy cập Menu chung (`hasMenuAccess`).
  final String? action;

  /// Phiên đăng nhập tùy chọn (mặc định lấy từ `AuthSessionStore.current`).
  final AuthSession? session;

  /// Hàm dựng UI nhận cờ boolean `hasPermission`.
  final Widget Function(BuildContext context, bool hasPermission)? builder;

  /// Widget con được hiển thị khi người dùng CÓ quyền.
  final Widget? child;

  /// Widget hiển thị khi người dùng KHÔNG CÓ quyền (mặc định là SizedBox.shrink()).
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final currentSession = session ?? AuthSessionStore.current;
    final bool permitted;

    if (currentSession == null) {
      permitted = false;
    } else if (action != null && action!.trim().isNotEmpty) {
      permitted = currentSession.hasPermission(menuCode, action!);
    } else {
      permitted = currentSession.hasMenuAccess(menuCode);
    }

    // PermissionBuilder dành cho CTA/widget nhỏ. Nó không thay thế kiểm tra
    // quyền lần hai bên trong function mutation trước khi gọi repository.
    if (builder != null) {
      return builder!(context, permitted);
    }

    if (permitted) {
      return child ?? const SizedBox.shrink();
    }

    return fallback;
  }
}

/// Widget bọc bảo vệ cả màn hình hoặc Route.
/// Nếu người dùng có quyền ➔ Hiển thị [child].
/// Nếu người dùng không có quyền ➔ Hiển thị [fallback] (Màn hình 403 PermissionDeniedScreen).
class PermissionGuard extends StatelessWidget {
  const PermissionGuard({
    required this.menuCode,
    required this.child,
    this.action,
    this.session,
    this.fallback,
    super.key,
  });

  final String menuCode;
  final String? action;
  final AuthSession? session;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final currentSession = session ?? AuthSessionStore.current;
    final bool permitted;

    if (currentSession == null) {
      permitted = false;
    } else if (action != null && action!.trim().isNotEmpty) {
      permitted = currentSession.hasPermission(menuCode, action!);
    } else {
      // A screen guard always requires explicit READ. Menu presence or a
      // mutation-only permission must not make list/detail content accessible.
      permitted = currentSession.hasReadAccess(menuCode);
    }

    // Chỉ dựng child sau khi pass guard để initState của feature không thể tải
    // dữ liệu/API trước rồi mới hiện màn "không có quyền".
    if (permitted) {
      return child;
    }

    return fallback ?? PermissionDeniedScreen(menuCode: menuCode);
  }
}
