import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/milling/data/api_milling_repository.dart';
import 'package:stocklite/features/milling/data/milling_repository.dart';
import 'package:stocklite/features/milling/models/milling_order.dart';
import 'package:stocklite/features/milling/presentation/screens/milling_create_order_screen.dart';

import 'support/fake_api_client.dart';

void main() {
  group('Milling create order API', () {
    setUp(() {
      AuthSessionStore.current = const AuthSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        user: AuthUser(id: 1, fullName: 'Tester', email: 'test@example.com'),
      );
    });

    tearDown(() => AuthSessionStore.current = null);

    test('creates a draft with the backend contract only', () async {
      final client = FakeApiClient(
        onPost: (path, body, token) async {
          expect(path, '/api/v1/milling-orders');
          expect(token, 'access-token');
          expect(body, {
            'warehouseId': 7,
            'riceVarietyId': 12,
            'reason': 'Mobile draft',
            'expectedYield': 0.65,
            'targetRiceKg': 650.0,
            'moisturePercent': 14.5,
            'millingCost': 120000.0,
            'incidentalCost': 30000.0,
            'expectedCompletionDate': '2026-08-21T00:00:00.000',
          });
          return {'isSucceeded': true, 'resources': 44};
        },
      );

      final id = await ApiMillingRepository(apiClient: client).createOrder(
        lot: const MillingPaddyLotOption(
          id: 101,
          code: 'LOT-101',
          warehouseId: 7,
          warehouseName: 'Kho A',
          riceVarietyId: 12,
          remainingWeightKg: 1000,
        ),
        inputWeightKg: 1000,
        expectedYield: 0.65,
        reason: 'Mobile draft',
        moisturePercent: 14.5,
        millingCost: 120000,
        incidentalCost: 30000,
        expectedCompletionDate: DateTime(2026, 8, 21),
      );

      expect(id, 44);
      expect(client.calls.map((call) => call.path), ['/api/v1/milling-orders']);
    });

    test('rejects weight beyond the selected lot before sending', () async {
      final client = FakeApiClient();
      await expectLater(
        ApiMillingRepository(apiClient: client).createOrder(
          lot: const MillingPaddyLotOption(
            id: 101,
            code: 'LOT-101',
            warehouseId: 7,
            warehouseName: 'Kho A',
            riceVarietyId: 12,
            remainingWeightKg: 100,
          ),
          inputWeightKg: 101,
          expectedYield: 0.65,
        ),
        throwsA(isA<MillingApiException>()),
      );
      expect(client.calls, isEmpty);
    });
  });

  testWidgets('renders lookup form and does not select a lot by default',
      (tester) async {
    final repository = _CreateRepository();
    await tester.pumpWidget(
      MaterialApp(home: MillingCreateOrderScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tạo lệnh xay'), findsOneWidget);
    expect(find.text('Chọn kho'), findsOneWidget);
    expect(find.text('Chọn lô lúa'), findsOneWidget);
    expect(repository.created, isFalse);
  });
}

class _CreateRepository extends MockMillingRepository {
  bool created = false;

  @override
  Future<List<MillingPaddyLotOption>> getPaddyLots() async => const [
        MillingPaddyLotOption(
          id: 101,
          code: 'LOT-101',
          warehouseId: 7,
          warehouseName: 'Kho A',
          riceVarietyId: 12,
          riceVarietyName: 'OM5451',
          remainingWeightKg: 1000,
        ),
      ];

  @override
  Future<int> createOrder({
    required MillingPaddyLotOption lot,
    required double inputWeightKg,
    required double expectedYield,
    String? reason,
    double? moisturePercent,
    double? millingCost,
    double? incidentalCost,
    DateTime? expectedCompletionDate,
  }) async {
    created = true;
    return 44;
  }
}
