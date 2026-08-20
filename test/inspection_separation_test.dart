import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/routes/app_routes.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/home/presentation/widgets/home_today_tab.dart';

void main() {
  tearDown(() => AuthSessionStore.current = null);

  testWidgets('home hides quality inspection and keeps stocktake route',
      (tester) async {
    AuthSessionStore.current = AuthSession(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      user: AuthUser(
        id: 1,
        fullName: 'Stocktake only',
        email: 'stocktake@test.local',
        roles: const [UserRole(id: 4, code: 'OWNER', name: 'Owner')],
        permissions: const [
          UserPermission(
            menuId: 10,
            menuCode: 'STOCKTAKE',
            actions: {'READ'},
          ),
        ],
        menus: const [
          UserMenu(id: 10, code: 'STOCKTAKE', name: 'Stocktake'),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: HomeTodayTab()),
        routes: {
          AppRoutes.stocktake: (_) =>
              const Scaffold(body: Text('STOCKTAKE_ROUTE')),
        },
      ),
    );

    expect(
        find.byKey(const ValueKey(AppRoutes.qualityInspections)), findsNothing);
    final stocktake = find.byKey(const ValueKey(AppRoutes.stocktake));
    await tester.ensureVisible(stocktake);
    await tester.tap(stocktake);
    await tester.pumpAndSettle();
    expect(find.text('STOCKTAKE_ROUTE'), findsOneWidget);
  });
}
