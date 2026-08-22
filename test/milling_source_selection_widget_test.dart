import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stocklite/features/milling/data/milling_repository.dart';
import 'package:stocklite/features/milling/models/milling_order.dart';
import 'package:stocklite/features/milling/presentation/screens/milling_source_selection_screen.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';

void main() {
  setUp(() {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      user: AuthUser(
        id: 1,
        fullName: 'Tester',
        email: 'tester@example.com',
        permissions: [
          UserPermission(
            menuId: 61,
            menuCode: 'MILLING_ORDERS',
            actions: {'READ', 'UPDATE'},
          ),
        ],
      ),
    );
  });

  tearDown(() => AuthSessionStore.current = null);

  testWidgets('suggestion is explicit and never reserves or starts',
      (tester) async {
    final repository = _SourceRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    final suggestionButton = find.ancestor(
      of: find.byIcon(Icons.auto_awesome),
      matching: find.byType(OutlinedButton),
    );
    expect(suggestionButton, findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(repository.suggestionCalls, 1);
    expect(repository.reserveCalls, 0);
    expect(repository.startCalls, 0);
    expect(find.textContaining('100.0 kg'), findsWidgets);
    expect(find.textContaining('Còn thiếu'), findsNothing);

    await tester.tap(suggestionButton);
    await tester.pumpAndSettle();

    expect(repository.suggestionCalls, 2);
    expect(repository.reserveCalls, 0);
    expect(repository.startCalls, 0);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repository.reserveCalls, 1);
    expect(repository.startCalls, 0);
  });

  testWidgets('empty suggestion renders empty state without fake selection',
      (tester) async {
    final repository = _SourceRepository(empty: true);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không có bao lúa phù hợp'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(repository.reserveCalls, 0);
    expect(repository.startCalls, 0);
  });

  testWidgets('suggestion error exposes retry and does not mutate',
      (tester) async {
    final repository = _SourceRepository(failOnce: true);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(repository.reserveCalls, 0);
    expect(repository.startCalls, 0);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(repository.suggestionCalls, 2);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(repository.reserveCalls, 0);
  });
}

MaterialApp _app(MillingRepository repository) => MaterialApp(
      home: MillingSourceSelectionScreen(
        order: const MillingOrder(
          id: 21,
          millingCode: 'MO-21',
          inputLotCode: 'LOT-01',
          inputWeightKg: 100,
          warehouseZone: 'Kho A',
          locationCode: 'A01',
          scaleCode: 'Cân thủ công',
          riceBags: [],
          branBags: [],
          statusCode: 'DRAFT',
          warehouseId: 7,
          riceVarietyName: 'OM5451',
        ),
        repository: repository,
      ),
    );

class _SourceRepository extends MockMillingRepository {
  _SourceRepository({this.empty = false, this.failOnce = false});

  final bool empty;
  bool failOnce;
  int suggestionCalls = 0;
  int reserveCalls = 0;
  int startCalls = 0;

  @override
  Future<MillingSourceSuggestion> getSourceSuggestion(int orderId) async {
    suggestionCalls++;
    if (failOnce) {
      failOnce = false;
      throw StateError('suggestion unavailable');
    }
    if (empty) {
      return const MillingSourceSuggestion(requiredWeightKg: 100, columns: []);
    }
    return const MillingSourceSuggestion(
      requiredWeightKg: 100,
      columns: [
        MillingSourceColumn(
          locationId: 12,
          locationCode: 'A01',
          bags: [
            MillingSourceBag(
              id: 101,
              bagNo: 1,
              weightKg: 50,
              status: 'STORED',
              selected: true,
            ),
            MillingSourceBag(
              id: 102,
              bagNo: 2,
              weightKg: 50,
              status: 'STORED',
              selected: true,
            ),
            MillingSourceBag(
              id: 103,
              bagNo: 3,
              weightKg: 50,
              status: 'RESERVED',
              selected: false,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<void> reserveOrder(
    int orderId,
    List<MillingSourceColumn> columns,
  ) async {
    reserveCalls++;
  }

  @override
  Future<void> startOrder(
    int orderId, {
    required String machineRef,
    int? operatorId,
  }) async {
    startCalls++;
  }
}
