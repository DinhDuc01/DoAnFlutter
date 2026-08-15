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

    test('Regular user checks specific roles, permissions, and menu access', () {
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

    test('AuthSession serialization and deserialization retains roles & permissions', () {
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
