import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/kho/data/stock_take_repository.dart';
import 'package:stocklite/features/kho/models/stock_take.dart';
import 'package:stocklite/features/kho/presentation/screens/stock_take_list_screen.dart';

void main() {
  tearDown(() => AuthSessionStore.current = null);

  testWidgets('READ-only stock take hides both create entry points',
      (tester) async {
    AuthSessionStore.current = _session(const {'READ'});
    final repository = _ListOnlyStockTakeRepository();

    await tester.pumpWidget(
      MaterialApp(home: StockTakeListScreen(repository: repository)),
    );
    await tester.pump();

    expect(find.byKey(const Key('stock_take_create_header')), findsNothing);
    expect(find.byKey(const Key('stock_take_create_fab')), findsNothing);
    expect(repository.listCalls, 1);
    expect(repository.mutationCalls, 0);
  });

  testWidgets('CREATE permission shows both create entry points',
      (tester) async {
    AuthSessionStore.current = _session(const {'READ', 'CREATE'});
    final repository = _ListOnlyStockTakeRepository();

    await tester.pumpWidget(
      MaterialApp(home: StockTakeListScreen(repository: repository)),
    );
    await tester.pump();

    expect(find.byKey(const Key('stock_take_create_header')), findsOneWidget);
    expect(find.byKey(const Key('stock_take_create_fab')), findsOneWidget);
    expect(repository.mutationCalls, 0);
  });
}

AuthSession _session(Set<String> actions) => AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: AuthUser(
        id: 1,
        fullName: 'Warehouse user',
        email: 'warehouse@test.local',
        permissions: [
          UserPermission(
            menuId: 1,
            menuCode: 'STOCKTAKE',
            actions: actions,
          ),
        ],
      ),
    );

class _ListOnlyStockTakeRepository implements StockTakeRepository {
  int listCalls = 0;
  int mutationCalls = 0;

  @override
  Future<List<StockTakeSummaryRow>> getStockTakes() async {
    listCalls++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    mutationCalls++;
    return super.noSuchMethod(invocation);
  }
}
