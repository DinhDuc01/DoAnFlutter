import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/api/api_client.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/stock_take/data/stock_take_repository.dart';
import 'package:stocklite/features/stock_take/models/stock_take.dart';
import 'package:stocklite/features/stock_take/data/api_stock_take_repository.dart';

import 'support/fake_api_client.dart';

void main() {
  setUp(() => AuthSessionStore.current = _session());
  tearDown(() => AuthSessionStore.current = null);

  group('NewApiStockTakeRepository.getStockTakesPaged', () {
    test('reads a paged list and returns page data', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'resources': {
            'data': [
              _summary(id: 3, code: 'ST-03'),
              _summary(id: 9, code: 'ST-09'),
            ],
            'recordsTotal': 2,
            'recordsFiltered': 2,
          },
        },
      );

      final page = await ApiStockTakeRepository(apiClient: client).getStockTakesPaged(
        start: 0,
        length: 20,
      );

      expect(page.items.map((r) => r.stCode), ['ST-03', 'ST-09']);
      expect(client.calls.single.path, '/api/v1/stocktakes/paged-advanced');
      expect(client.calls.single.token, 'token');
    });

    test('refuses to call the API without a logged in user', () async {
      AuthSessionStore.current = null;
      final client = FakeApiClient();

      await expectLater(
        ApiStockTakeRepository(apiClient: client).getStockTakesPaged(start: 0, length: 20),
        throwsA(isA<ApiException>()),
      );
      expect(client.calls, isEmpty);
    });
  });

  group('NewApiStockTakeRepository.create', () {
    test('sends correct create request body and returns id', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {'resources': 42},
      );

      final id = await ApiStockTakeRepository(apiClient: client).create(
        warehouseId: 3,
        scope: StockTakeScope.column,
        locationId: 7,
        note: 'Kiểm cuối tháng',
      );

      expect(id, 42);
      final body = client.calls.single.body!;
      expect(client.calls.single.path, '/api/v1/stocktakes');
      expect(body['warehouseId'], 3);
      expect(body['scopeType'], 'COLUMN');
      expect(body['locationId'], 7);
      expect(body['note'], 'Kiểm cuối tháng');
      expect(body['stockTakeItems'], isEmpty);
      expect(body['stockTakeStatusId'], 0);
    });
  });
}

Map<String, dynamic> _summary({required int id, required String code}) => {
      'id': id,
      'stCode': code,
      'warehouseName': 'Kho A',
      'stockTakeStatusCode': 'DRAFT',
      'stockTakeStatusName': 'Nháp',
      'createdDate': '2026-08-14T08:00:00',
    };

AuthSession _session() {
  return const AuthSession(
    accessToken: 'token',
    refreshToken: 'refresh',
    user: AuthUser(id: 1, fullName: 'Tester', email: 'tester@example.com'),
  );
}
