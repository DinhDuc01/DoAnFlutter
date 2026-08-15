import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/screens/permission_denied_screen.dart';
import 'package:stocklite/core/widgets/permission_guard.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';

void main() {
  const adminSession = AuthSession(
    accessToken: 'admin-token',
    refreshToken: 'admin-refresh',
    user: AuthUser(
      id: 1,
      fullName: 'Admin User',
      email: 'admin@stocklite.com',
      roles: [UserRole(id: 1001, code: 'ADMIN', name: 'Admin')],
    ),
  );

  const restrictedSession = AuthSession(
    accessToken: 'user-token',
    refreshToken: 'user-refresh',
    user: AuthUser(
      id: 2,
      fullName: 'Công nhân xay',
      email: 'miller@stocklite.com',
      roles: [UserRole(id: 1002, code: 'WORKER', name: 'Công nhân')],
      permissions: [
        UserPermission(
          menuId: 61,
          menuCode: 'MILLING_ORDERS',
          actions: {'READ', 'UPDATE'},
        ),
      ],
      menus: [
        UserMenu(id: 61, code: 'MILLING_ORDERS', name: 'Lệnh xay xát'),
      ],
    ),
  );

  group('PermissionBuilder Widget Tests', () {
    testWidgets('renders child when user has required action permission',
        (widgetTester) async {
      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionBuilder(
              menuCode: 'MILLING_ORDERS',
              action: 'UPDATE',
              session: restrictedSession,
              child: const Text('Nút Sửa Lệnh Xay'),
            ),
          ),
        ),
      );

      expect(find.text('Nút Sửa Lệnh Xay'), findsOneWidget);
    });

    testWidgets('renders fallback when user lacks required action permission',
        (widgetTester) async {
      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionBuilder(
              menuCode: 'MILLING_ORDERS',
              action: 'DELETE',
              session: restrictedSession,
              fallback: const Text('Không có quyền Xóa'),
              child: const Text('Nút Xóa Lệnh Xay'),
            ),
          ),
        ),
      );

      expect(find.text('Nút Xóa Lệnh Xay'), findsNothing);
      expect(find.text('Không có quyền Xóa'), findsOneWidget);
    });

    testWidgets('Admin user renders child for any action and menu',
        (widgetTester) async {
      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionBuilder(
              menuCode: 'STOCKTAKE',
              action: 'CREATE',
              session: adminSession,
              child: const Text('Nút Tạo Phiếu Kiểm Kê'),
            ),
          ),
        ),
      );

      expect(find.text('Nút Tạo Phiếu Kiểm Kê'), findsOneWidget);
    });
  });

  group('PermissionGuard & PermissionDeniedScreen Tests', () {
    testWidgets('PermissionGuard renders child when permitted',
        (widgetTester) async {
      await widgetTester.pumpWidget(
        MaterialApp(
          home: PermissionGuard(
            menuCode: 'MILLING_ORDERS',
            session: restrictedSession,
            child: const Scaffold(body: Text('Màn hình Xay xát')),
          ),
        ),
      );

      expect(find.text('Màn hình Xay xát'), findsOneWidget);
      expect(find.byType(PermissionDeniedScreen), findsNothing);
    });

    testWidgets('PermissionGuard renders PermissionDeniedScreen when unpermitted',
        (widgetTester) async {
      await widgetTester.pumpWidget(
        MaterialApp(
          home: PermissionGuard(
            menuCode: 'REPORTS',
            session: restrictedSession,
            child: const Scaffold(body: Text('Màn hình Báo cáo')),
          ),
        ),
      );

      expect(find.text('Màn hình Báo cáo'), findsNothing);
      expect(find.byType(PermissionDeniedScreen), findsOneWidget);
      expect(find.textContaining('403 - Khóa truy cập'), findsOneWidget);
      expect(find.textContaining('REPORTS'), findsOneWidget);
    });
  });
}
