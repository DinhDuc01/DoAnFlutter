import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/routes/app_routes.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/milling/data/milling_repository.dart';
import 'package:stocklite/features/milling/models/milling_order.dart';
import 'package:stocklite/features/milling/presentation/screens/milling_preparation_screen.dart';
import 'package:stocklite/features/home/presentation/widgets/home_today_tab.dart';

void main() {
  tearDown(() => AuthSessionStore.current = null);

  test('mock milling order calculates output totals', () async {
    final order = await MockMillingRepository().getActiveOrder();
    expect(order.totalRiceKg, 250);
    expect(order.totalBranKg, 99.5);
    expect(order.riceYieldPercent, 5);
    expect(order.statusCode, 'MILLING');
  });

  testWidgets('READ-only milling session cannot see mutation actions',
      (tester) async {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      user: AuthUser(
        id: 21,
        fullName: 'Read only',
        email: 'readonly@test.local',
        permissions: [
          UserPermission(
            menuId: 61,
            menuCode: 'MILLING_ORDERS',
            actions: {'READ'},
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MillingPreparationScreen(repository: MockMillingRepository()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byTooltip('Tạo lệnh xay'), findsNothing);
    await tester.tap(find.textContaining('MO-2026-021').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Sửa lệnh'), findsNothing);
    expect(find.byKey(const Key('milling_enter_output_button')), findsNothing);
  });

  testWidgets('MILLING detail opens the multi-output result screen',
      (tester) async {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      user: AuthUser(
        id: 20,
        fullName: 'Milling worker',
        email: 'milling@test.local',
        permissions: [
          UserPermission(
            menuId: 61,
            menuCode: 'MILLING_ORDERS',
            actions: {'READ', 'UPDATE'},
          ),
        ],
      ),
    );
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MillingPreparationScreen(repository: MockMillingRepository()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.textContaining('MO-2026-021').first);
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('milling_enter_output_button')), findsOneWidget);
    expect(find.byKey(const Key('milling_output_section')), findsNothing);
    expect(
        find.byKey(const Key('milling_weighing_confirm_sticky')), findsNothing);
    await tester.tap(find.byKey(const Key('milling_enter_output_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nhập kết quả xay'), findsOneWidget);
  });

  testWidgets('home milling shortcut opens the dedicated milling route',
      (tester) async {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      user: AuthUser(
        id: 20,
        fullName: 'Milling worker',
        email: 'milling@test.local',
        roles: [UserRole(id: 9, code: 'MILLING', name: 'Milling')],
        permissions: [
          UserPermission(
            menuId: 61,
            menuCode: 'MILLING_ORDERS',
            actions: {'READ'},
          ),
        ],
      ),
    );
    final observer = _RouteObserver();
    await tester.pumpWidget(
      MaterialApp(
        home: const HomeTodayTab(),
        navigatorObservers: [observer],
        routes: {
          AppRoutes.milling: (_) => MillingPreparationScreen(
                key: const Key('milling_preparation_screen'),
                repository: MockMillingRepository(),
              ),
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final millingShortcut = find.byKey(const ValueKey(AppRoutes.milling));
    await tester.ensureVisible(millingShortcut);
    await tester.tap(millingShortcut);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(observer.pushedRoutes, contains(AppRoutes.milling));
  });

  testWidgets('Start milling button starts immediately without showing dialog',
      (tester) async {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      user: AuthUser(
        id: 20,
        fullName: 'Milling worker',
        email: 'milling@test.local',
        permissions: [
          UserPermission(
            menuId: 61,
            menuCode: 'MILLING_ORDERS',
            actions: {'READ', 'UPDATE'},
          ),
        ],
      ),
    );

    final repo = _StartTestRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MillingPreparationScreen(repository: repo),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.textContaining('MO-2026-022').first);
    await tester.pumpAndSettle();

    final startButton = find.text('Bắt đầu xay');
    expect(startButton, findsOneWidget);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    // Verify startOrder was called directly with default machine and no AlertDialog was shown
    expect(repo.startedOrderId, 22);
    expect(repo.startedMachineRef, 'máy xay 1');
    expect(find.byType(AlertDialog), findsNothing);
  });
}

class _StartTestRepository extends MockMillingRepository {
  int? startedOrderId;
  String? startedMachineRef;

  @override
  Future<MillingOrderPage> getMillingOrderPage({
    String search = '',
    int? statusId,
    int? warehouseId,
    int start = 0,
    int length = 20,
  }) async =>
      MillingOrderPage(
        orders: [
          MillingOrder(
            id: 22,
            millingCode: 'MO-2026-022',
            warehouseId: 1,
            inputLotCode: 'LOT-22',
            inputWeightKg: 5000,
            warehouseZone: 'Khu A',
            locationCode: 'LOC-01',
            scaleCode: 'SCALE-01',
            totalRiceOutputKg: 3400,
            yieldRateUsed: 0.68,
            statusCode: 'RESERVED',
            riceBags: const [],
            branBags: const [],
            brokenBags: const [],
          ),
        ],
        recordsTotal: 1,
        recordsFiltered: 1,
      );

  @override
  Future<MillingOrder> getMillingOrderDetail(int id) async => MillingOrder(
        id: 22,
        millingCode: 'MO-2026-022',
        warehouseId: 1,
        inputLotCode: 'LOT-22',
        inputWeightKg: 5000,
        warehouseZone: 'Khu A',
        locationCode: 'LOC-01',
        scaleCode: 'SCALE-01',
        totalRiceOutputKg: 3400,
        yieldRateUsed: 0.68,
        statusCode: 'RESERVED',
        riceBags: const [],
        branBags: const [],
        brokenBags: const [],
      );

  @override
  Future<void> startOrder(
    int orderId, {
    required String machineRef,
    int? operatorId,
  }) async {
    startedOrderId = orderId;
    startedMachineRef = machineRef;
  }
}

class _RouteObserver extends NavigatorObserver {
  final pushedRoutes = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}
