import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/routes/app_routes.dart';
import 'package:stocklite/core/widgets/permission_guard.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/sales_orders/data/sales_order_repository.dart';
import 'package:stocklite/features/sales_orders/models/sales_order.dart';
import 'package:stocklite/features/sales_orders/presentation/screens/sales_order_list_screen.dart';
import 'package:stocklite/features/home/presentation/widgets/home_today_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AuthSessionStore.current = null;
  });

  group('permission CTA matrix outside Stock Take', () {
    const featureMenus = <String>[
      'RICE_PURCHASE',
      'DEBTS',
      'QUALITY_INSPECTIONS',
      'PADDY_LOTS',
      'SALE_ORDERS',
      'OUTBOUND_ORDERS',
      'INBOUND_ORDERS',
    ];

    for (final menuCode in featureMenus) {
      testWidgets('$menuCode shows CTA with matching permission',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PermissionBuilder(
                menuCode: menuCode,
                action: 'CREATE',
                session:
                    _session(menuCode: menuCode, actions: const {'CREATE'}),
                child: const SizedBox(
                  key: Key('guarded_mutation_cta'),
                  child: Text('mutation'),
                ),
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('guarded_mutation_cta')), findsOneWidget);
      });

      testWidgets('$menuCode hides CTA without matching action',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PermissionBuilder(
                menuCode: menuCode,
                action: 'CREATE',
                session: _session(menuCode: menuCode, actions: const {'READ'}),
                child: const SizedBox(
                  key: Key('guarded_mutation_cta'),
                  child: Text('mutation'),
                ),
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('guarded_mutation_cta')), findsNothing);
      });
    }

    testWidgets('unknown or null session denies dangerous CTA', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PermissionBuilder(
              menuCode: 'OUTBOUND_ORDERS',
              action: 'UPDATE',
              child: SizedBox(key: Key('guarded_mutation_cta')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('guarded_mutation_cta')), findsNothing);
    });
  });

  group('Sales Order production create CTA', () {
    testWidgets('CREATE permission renders create CTA without network calls',
        (tester) async {
      AuthSessionStore.current =
          _session(menuCode: 'SALE_ORDERS', actions: const {'READ', 'CREATE'});
      final repository = _FakeSalesOrderRepository();

      await tester.pumpWidget(
        MaterialApp(home: SalesOrderListScreen(repository: repository)),
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(repository.getPagedCalls, 1);
      expect(repository.mutationCalls, 0);
    });

    testWidgets('missing CREATE hides create CTA and does not mutate',
        (tester) async {
      AuthSessionStore.current =
          _session(menuCode: 'SALE_ORDERS', actions: const {'READ'});
      final repository = _FakeSalesOrderRepository();

      await tester.pumpWidget(
        MaterialApp(home: SalesOrderListScreen(repository: repository)),
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(repository.getPagedCalls, 1);
      expect(repository.mutationCalls, 0);
    });
  });

  testWidgets('nested SALES session renders the Sales Order home shortcut',
      (tester) async {
    final user = AuthUser.fromJson({
      'id': 20,
      'fullName': 'Sales User',
      'email': 'sales@test.local',
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
          ],
        },
      ],
      'permissions': [
        {
          'menuId': 41,
          'actionIds': [1001, 1002, 1003]
        },
      ],
    });
    AuthSessionStore.current = AuthSession(
      accessToken: 'sales-token',
      refreshToken: 'sales-refresh',
      user: user,
    );

    await tester.pumpWidget(const MaterialApp(home: HomeTodayTab()));

    expect(find.byKey(const ValueKey(AppRoutes.salesOrders)), findsOneWidget);
  });
}

AuthSession _session({
  required String menuCode,
  required Set<String> actions,
}) {
  return AuthSession(
    accessToken: 'test-token',
    refreshToken: 'test-refresh',
    user: AuthUser(
      id: 10,
      fullName: 'Widget Test User',
      email: 'widget@test.local',
      roles: const [UserRole(id: 4, code: 'OWNER', name: 'Owner')],
      permissions: [
        UserPermission(
          menuId: 100,
          menuCode: menuCode,
          actions: actions,
        ),
      ],
      menus: [UserMenu(id: 100, code: menuCode, name: menuCode)],
    ),
  );
}

class _FakeSalesOrderRepository implements SalesOrderRepository {
  int getPagedCalls = 0;
  int mutationCalls = 0;

  @override
  Future<SalesOrderPage> getPaged({
    String? keyword,
    int? statusId,
    String? channel,
    int page = 1,
    int pageSize = 20,
  }) async {
    getPagedCalls++;
    return const SalesOrderPage(total: 0, items: []);
  }

  @override
  Future<SalesOrderDetail> getById(int id) => throw UnimplementedError();

  @override
  Future<void> confirm(int id) async => mutationCalls++;

  @override
  Future<CreatedSalesOrder> create(CreateSalesOrderInput input) async {
    mutationCalls++;
    return const CreatedSalesOrder(id: 1, soCode: 'SO-TEST', totalAmount: 0);
  }

  @override
  Future<void> reserve(int id) async => mutationCalls++;

  @override
  Future<void> cancel(int id, {required String reason}) async =>
      mutationCalls++;

  @override
  Future<int> createOutbound(int id, List<CreateOutboundLine> items) async {
    mutationCalls++;
    return 1;
  }

  @override
  Future<List<SalesCustomerOption>> getCustomers() async => const [];

  @override
  Future<List<SalesWarehouseOption>> getWarehouses() async => const [];

  @override
  Future<List<SalesProductOption>> getProductVariants(
          {String keyword = ''}) async =>
      const [];
}
