import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stocklite/core/api/api_client.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/milling/data/api_milling_repository.dart';
import 'package:stocklite/features/milling/data/milling_repository.dart';
import 'package:stocklite/features/milling/models/milling_order.dart';
import 'package:stocklite/features/milling/presentation/screens/milling_create_order_screen.dart';
import 'package:stocklite/features/sales_orders/data/sales_order_repository.dart';
import 'package:stocklite/features/sales_orders/models/sales_order.dart';
import 'package:stocklite/features/thu_mua/data/paddy_variety_api.dart';

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
            'salesOrderId': 456,
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
        warehouseId: 7,
        riceVarietyId: 12,
        expectedYield: 0.65,
        targetRiceKg: 650.0,
        salesOrderId: 456,
        lot: const MillingPaddyLotOption(
          id: 101,
          code: 'LOT-101',
          warehouseId: 7,
          warehouseName: 'Kho A',
          riceVarietyId: 12,
          remainingWeightKg: 1000,
        ),
        inputWeightKg: 1000,
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
          warehouseId: 7,
          riceVarietyId: 12,
          expectedYield: 0.65,
          targetRiceKg: 656.5,
          lot: const MillingPaddyLotOption(
            id: 101,
            code: 'LOT-101',
            warehouseId: 7,
            warehouseName: 'Kho A',
            riceVarietyId: 12,
            remainingWeightKg: 100,
          ),
          inputWeightKg: 1000,
        ),
        throwsA(isA<MillingApiException>()),
      );
      expect(client.calls, isEmpty);
    });

    test('reserves physical bags with columns and never starts implicitly',
        () async {
      final client = FakeApiClient(
        onPost: (path, body, token) async {
          expect(token, 'access-token');
          if (path == '/api/v1/milling-orders/44/reserve') {
            expect(body, {
              'columns': [
                {
                  'locationId': 10,
                  'bagIds': [101, 102],
                },
              ],
            });
          }
          return {'isSucceeded': true};
        },
      );
      final repository = ApiMillingRepository(apiClient: client);

      await repository.reserveOrder(44, [
        const MillingSourceColumn(
          locationId: 10,
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
          ],
        ),
      ]);

      expect(
        client.calls.map((call) => call.path),
        ['/api/v1/milling-orders/44/reserve'],
      );
      expect(client.calls.any((call) => call.path.endsWith('/start')), isFalse);
    });

    test('does not treat reserve conflict as success', () async {
      final client = FakeApiClient(
        onPost: (path, body, token) async {
          throw const ApiException(
            message: 'Bao vừa được người khác giữ.',
            statusCode: 409,
          );
        },
      );

      await expectLater(
        ApiMillingRepository(apiClient: client).reserveOrder(
          44,
          const [
            MillingSourceColumn(
              locationId: 10,
              bags: [
                MillingSourceBag(
                  id: 101,
                  bagNo: 1,
                  weightKg: 50,
                  status: 'STORED',
                  selected: true,
                ),
              ],
            ),
          ],
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            409,
          ),
        ),
      );
    });
  });

  testWidgets('renders lookup form and does not select a lot by default',
      (tester) async {
    final repository = _CreateRepository();
    final salesOrderRepository = _FakeSalesOrderRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MillingCreateOrderScreen(
          repository: repository,
          salesOrderRepository: salesOrderRepository,
          riceVarietiesLoader: () async => const [
            RiceVarietyOption(id: 12, name: 'OM5451'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tạo lệnh xay'), findsOneWidget);
    expect(find.text('Chọn kho'), findsOneWidget);
    for (var i = 0;
        i < 4 && find.text('Chọn lô lúa (không bắt buộc)').evaluate().isEmpty;
        i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    expect(find.text('Chọn lô lúa (không bắt buộc)'), findsOneWidget);
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
  Future<List<MillingFilterOption>> getWarehouses() async => const [
        MillingFilterOption(id: 7, name: 'Kho A'),
      ];

  @override
  Future<int> createOrder({
    required int warehouseId,
    int? riceVarietyId,
    required double expectedYield,
    required double targetRiceKg,
    int? salesOrderId,
    MillingPaddyLotOption? lot,
    double? inputWeightKg,
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

class _FakeSalesOrderRepository implements SalesOrderRepository {
  @override
  Future<void> confirm(int id) async {}

  @override
  Future<SalesOrderPage> getPaged({
    String? keyword,
    int? statusId,
    String? channel,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const SalesOrderPage(total: 0, items: []);
  }

  @override
  Future<SalesOrderDetail> getById(int id) async {
    throw UnimplementedError();
  }

  @override
  Future<void> cancel(int id, {required String reason}) async {}

  @override
  Future<int> createOutbound(int id, List<CreateOutboundLine> items) async {
    return 0;
  }

  @override
  Future<CreatedSalesOrder> create(CreateSalesOrderInput input) async {
    return const CreatedSalesOrder(id: 1, soCode: 'SO-01', totalAmount: 0);
  }

  @override
  Future<void> reserve(int id) async {}

  @override
  Future<List<SalesCustomerOption>> getCustomers() async => const [];

  @override
  Future<List<SalesWarehouseOption>> getWarehouses() async => const [];

  @override
  Future<List<SalesProductOption>> getProductVariants({
    String keyword = '',
  }) async =>
      const [];
}
