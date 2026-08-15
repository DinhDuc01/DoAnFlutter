import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';

void main() {
  group('UserPermission & Action Parser Tests', () {
    test('parses action IDs 1001..1006 correctly into action string names', () {
      final perm = UserPermission.fromJson({
        'menuId': 61,
        'menuCode': 'MILLING_ORDERS',
        'actionIds': [1001, 1002, 1003, 1006],
      });

      expect(perm.menuCode, equals('MILLING_ORDERS'));
      expect(perm.hasAction('CREATE'), isTrue);
      expect(perm.hasAction('READ'), isTrue);
      expect(perm.hasAction('UPDATE'), isTrue);
      expect(perm.hasAction('APPROVE'), isTrue);
      expect(perm.hasAction('DELETE'), isFalse);
    });

    test('parses action string codes correctly', () {
      final perm = UserPermission.fromJson({
        'menuId': 34,
        'menuCode': 'STOCKTAKE',
        'actions': ['READ', 'CREATE'],
      });

      expect(perm.menuCode, equals('STOCKTAKE'));
      expect(perm.hasAction('READ'), isTrue);
      expect(perm.hasAction('CREATE'), isTrue);
      expect(perm.hasAction('UPDATE'), isFalse);
    });
  });

  group('AuthUser & AuthSession Permission Helpers', () {
    test('flattens nested sales menus and maps child permission ids', () {
      final user = AuthUser.fromJson({
        'id': 15,
        'fullName': 'Nhân viên bán hàng',
        'email': 'sales@stocklite.com',
        'roles': [
          {'id': 1013, 'name': 'Nhân viên bán hàng'},
        ],
        'menus': [
          {
            'id': 40,
            'code': 'SALES',
            'name': 'Bán hàng',
            'child': [
              {'id': 41, 'code': 'SALE_ORDERS', 'name': 'Đơn bán'},
              {'id': 42, 'code': 'OUTBOUND_ORDERS', 'name': 'Xuất kho / Giao'},
            ],
          },
        ],
        'permissions': [
          {
            'menuId': 41,
            'actionIds': [1001, 1002, 1003]
          },
          {
            'menuId': 42,
            'actionIds': [1002, 1003]
          },
        ],
      });

      expect(user.isMobileBlocked, isFalse);
      expect(user.hasMenuAccess('SALE_ORDERS'), isTrue);
      expect(user.hasPermission('SALE_ORDERS', 'CREATE'), isTrue);
      expect(user.hasPermission('SALE_ORDERS', 'UPDATE'), isTrue);
      expect(user.hasMenuAccess('OUTBOUND_ORDERS'), isTrue);
      expect(user.hasPermission('OUTBOUND_ORDERS', 'UPDATE'), isTrue);
      expect(user.menus.map((menu) => menu.code),
          containsAll(<String>['SALES', 'SALE_ORDERS', 'OUTBOUND_ORDERS']));
    });

    test('supports children alias in nested session menu payload', () {
      final user = AuthUser.fromJson({
        'id': 16,
        'fullName': 'Sales Alias',
        'email': 'sales-alias@stocklite.com',
        'roles': [
          {'id': 1013, 'name': 'Nhân viên bán hàng'},
        ],
        'menus': [
          {
            'id': 40,
            'code': 'SALES',
            'name': 'Bán hàng',
            'children': [
              {'id': 41, 'code': 'SALE_ORDERS', 'name': 'Đơn bán'},
            ],
          },
        ],
        'permissions': [
          {
            'menuId': 41,
            'actionIds': [1002]
          },
        ],
      });

      expect(user.hasMenuAccess('SALE_ORDERS'), isTrue);
      expect(user.hasPermission('SALE_ORDERS', 'READ'), isTrue);
    });

    test('maps Backend menuId/actionIds permissions to menu codes', () {
      final user = AuthUser.fromJson({
        'id': 7,
        'fullName': 'Nhân viên thu mua',
        'email': 'purchasing@stocklite.com',
        'roles': [
          {'id': 1011, 'name': 'Nhân viên thu mua'},
        ],
        'menus': [
          {'id': 16, 'code': 'RICE_PURCHASE', 'name': 'Lịch & Phiếu Mua'},
        ],
        'permissions': [
          {
            'menuId': 16,
            'actionIds': [1001, 1002, 1003, 1004]
          },
        ],
      });

      final session = AuthSession(
        accessToken: 'token-purchasing',
        refreshToken: 'refresh-purchasing',
        user: user,
      );

      expect(session.isAdmin, isFalse);
      expect(session.hasPermission('RICE_PURCHASE', 'CREATE'), isTrue);
      expect(session.hasPermission('RICE_PURCHASE', 'UPDATE'), isTrue);
      expect(session.hasPermission('RICE_PURCHASE', 'APPROVE'), isFalse);
    });

    test('empty permissions do not grant admin access', () {
      const user = AuthUser(
        id: 8,
        fullName: 'Người dùng chưa cấp quyền',
        email: 'user@stocklite.com',
        roles: [UserRole(id: 1002, code: 'END_USER', name: 'Người dùng')],
      );

      expect(user.isAdmin, isFalse);
      expect(user.hasMenuAccess('RICE_PURCHASE'), isFalse);
      expect(user.hasPermission('RICE_PURCHASE', 'CREATE'), isFalse);
    });

    test('auditor is blocked from the mobile app', () {
      const user = AuthUser(
        id: 9,
        fullName: 'Kiểm toán viên',
        email: 'auditor@stocklite.com',
        roles: [UserRole(id: 1003, code: 'AUDITOR', name: 'Kiểm toán viên')],
      );

      expect(user.isMobileBlocked, isTrue);
    });

    test('warehouse role keeps only warehouse permissions on mobile', () {
      final user = AuthUser.fromJson({
        'id': 10,
        'fullName': 'Nhân viên kho',
        'email': 'warehouse@stocklite.com',
        'roles': [
          {'id': 1012, 'name': 'Nhân viên kho'},
        ],
        'menus': [
          {'id': 32, 'code': 'INBOUND_ORDERS', 'name': 'Nhập kho'},
          {'id': 67, 'code': 'DEBTS', 'name': 'Công nợ'},
        ],
        'permissions': [
          {
            'menuId': 32,
            'actionIds': [1001, 1002, 1003]
          },
        ],
      });

      final session = AuthSession(
        accessToken: 'token-warehouse',
        refreshToken: 'refresh-warehouse',
        user: user,
      );

      expect(user.isMobileBlocked, isFalse);
      expect(user.isWarehouseWorker, isTrue);
      expect(session.hasPermission('INBOUND_ORDERS', 'CREATE'), isTrue);
      expect(session.hasPermission('INBOUND_ORDERS', 'UPDATE'), isTrue);
      expect(session.hasPermission('INBOUND_ORDERS', 'DELETE'), isFalse);
      expect(session.hasPermission('DEBTS', 'READ'), isFalse);
    });

    test('multi-role account is blocked when any role is restricted', () {
      const user = AuthUser(
        id: 11,
        fullName: 'Chủ cơ sở kiêm kiểm toán viên',
        email: 'multi-role@stocklite.com',
        roles: [
          UserRole(id: 1004, code: 'OWNER', name: 'Chủ cơ sở'),
          UserRole(id: 1003, code: 'AUDITOR', name: 'Kiểm toán viên'),
        ],
      );

      expect(user.isMobileBlocked, isTrue);
    });

    test('backend admin role without code is blocked by id and name', () {
      const user = AuthUser(
        id: 12,
        fullName: 'Quản trị viên',
        email: 'admin-no-code@stocklite.com',
        roles: [
          UserRole(id: 1001, code: 'QUẢN TRỊ VIÊN', name: 'Quản trị viên')
        ],
      );

      expect(user.isMobileBlocked, isTrue);
    });

    test('Admin user has all permissions and menu access', () {
      const user = AuthUser(
        id: 1,
        fullName: 'Quản trị viên',
        email: 'admin@stocklite.com',
        roles: [UserRole(id: 1001, code: 'ADMIN', name: 'Quản trị')],
        permissions: [],
      );

      const session = AuthSession(
        accessToken: 'token-admin',
        refreshToken: 'refresh-admin',
        user: user,
      );

      expect(session.isAdmin, isTrue);
      expect(session.hasRole('ADMIN'), isTrue);
      expect(session.hasMenuAccess('MILLING_ORDERS'), isTrue);
      expect(session.hasPermission('MILLING_ORDERS', 'DELETE'), isTrue);
      expect(session.hasPermission('ANY_MENU', 'ANY_ACTION'), isTrue);
    });

    test('Regular user checks specific roles, permissions, and menu access',
        () {
      const user = AuthUser(
        id: 2,
        fullName: 'Công nhân xay',
        email: 'miller@stocklite.com',
        roles: [UserRole(id: 1002, code: 'MILLER', name: 'Thủ kho xay xát')],
        permissions: [
          UserPermission(
            menuId: 61,
            menuCode: 'MILLING_ORDERS',
            actions: {'READ', 'UPDATE'},
          ),
          UserPermission(
            menuId: 34,
            menuCode: 'STOCKTAKE',
            actions: {'READ'},
          ),
        ],
        menus: [
          UserMenu(id: 61, code: 'MILLING_ORDERS', name: 'Lệnh xay xát'),
          UserMenu(id: 34, code: 'STOCKTAKE', name: 'Kiểm kê kho'),
        ],
      );

      const session = AuthSession(
        accessToken: 'token-worker',
        refreshToken: 'refresh-worker',
        user: user,
      );

      expect(session.isAdmin, isFalse);
      expect(session.hasRole('ADMIN'), isFalse);
      expect(session.hasRole('MILLER'), isTrue);

      // Milling permissions
      expect(session.hasMenuAccess('MILLING_ORDERS'), isTrue);
      expect(session.hasPermission('MILLING_ORDERS', 'READ'), isTrue);
      expect(session.hasPermission('MILLING_ORDERS', 'UPDATE'), isTrue);
      expect(session.hasPermission('MILLING_ORDERS', 'DELETE'), isFalse);

      // Stocktake permissions
      expect(session.hasMenuAccess('STOCKTAKE'), isTrue);
      expect(session.hasPermission('STOCKTAKE', 'READ'), isTrue);
      expect(session.hasPermission('STOCKTAKE', 'CREATE'), isFalse);

      // Unpermitted menu
      expect(session.hasMenuAccess('REPORTS'), isFalse);
      expect(session.hasPermission('REPORTS', 'READ'), isFalse);
    });

    test(
        'AuthSession serialization and deserialization retains roles & permissions',
        () {
      const originalSession = AuthSession(
        accessToken: 'acc-123',
        refreshToken: 'ref-456',
        user: AuthUser(
          id: 5,
          fullName: 'Nhân viên thu mua',
          email: 'thumua@stocklite.com',
          roles: [UserRole(id: 2, code: 'BUYER', name: 'Thu mua')],
          permissions: [
            UserPermission(
              menuId: 51,
              menuCode: 'RICE_PURCHASE',
              actions: {'READ', 'CREATE', 'UPDATE'},
            ),
          ],
          menus: [
            UserMenu(id: 51, code: 'RICE_PURCHASE', name: 'Thu mua lúa'),
          ],
        ),
      );

      final jsonMap = originalSession.toJson();
      final restoredSession = AuthSession.fromJson(jsonMap);

      expect(restoredSession.accessToken, equals('acc-123'));
      expect(restoredSession.user.fullName, equals('Nhân viên thu mua'));
      expect(restoredSession.hasRole('BUYER'), isTrue);
      expect(restoredSession.hasMenuAccess('RICE_PURCHASE'), isTrue);
      expect(restoredSession.hasPermission('RICE_PURCHASE', 'CREATE'), isTrue);
      expect(restoredSession.hasPermission('RICE_PURCHASE', 'DELETE'), isFalse);
    });
  });
}
