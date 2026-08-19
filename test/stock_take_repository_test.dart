import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/api/api_client.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/kho/data/stock_take_repository.dart';
import 'package:stocklite/features/kho/models/stock_take.dart';

import 'support/fake_api_client.dart';

void main() {
  setUp(() => AuthSessionStore.current = _session());
  tearDown(() => AuthSessionStore.current = null);

  group('ApiStockTakeRepository.getStockTakes', () {
    test('reads a plain list and shows the newest slip first', () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {
          'resources': [
            _summary(id: 3, code: 'ST-03'),
            _summary(id: 9, code: 'ST-09'),
          ],
        },
      );

      final rows = await ApiStockTakeRepository(apiClient: client).getStockTakes();

      expect(rows.map((r) => r.code), ['ST-09', 'ST-03']);
      expect(client.calls.single.path, '/api/v1/stocktakes');
      expect(client.calls.single.token, 'token');
    });

    test('also reads the paged shape (resources.data)', () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {
          'resources': {
            'data': [_summary(id: 1, code: 'ST-01')],
            'totalRecords': 1,
          },
        },
      );

      final rows = await ApiStockTakeRepository(apiClient: client).getStockTakes();

      expect(rows.single.code, 'ST-01');
      expect(rows.single.isDraft, isTrue);
    });

    test('refuses to call the API without a logged in user', () async {
      AuthSessionStore.current = null;
      final client = FakeApiClient();

      await expectLater(
        ApiStockTakeRepository(apiClient: client).getStockTakes(),
        throwsA(isA<StockTakeException>()),
      );
      // Không được đụng tới mạng khi chưa có token.
      expect(client.calls, isEmpty);
    });

    test('marks a server-side failure as transient so the UI offers a retry',
        () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async =>
            throw const ApiException(message: 'Bad gateway', statusCode: 502),
      );

      await expectLater(
        ApiStockTakeRepository(apiClient: client).getStockTakes(),
        throwsA(
          isA<StockTakeException>()
              .having((e) => e.isTransient, 'isTransient', isTrue)
              .having((e) => e.message, 'message', 'Bad gateway'),
        ),
      );
    });

    test('a rejected request is not transient — retrying will not help',
        () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async =>
            throw const ApiException(message: 'Không đủ quyền', statusCode: 403),
      );

      await expectLater(
        ApiStockTakeRepository(apiClient: client).getStockTakes(),
        throwsA(
          isA<StockTakeException>()
              .having((e) => e.isTransient, 'isTransient', isFalse),
        ),
      );
    });
  });

  group('ApiStockTakeRepository.create', () {
    test('lets the backend snapshot the slip instead of sending client rows',
        () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {'resources': 42},
      );

      final id = await ApiStockTakeRepository(apiClient: client).create(
        warehouseId: 3,
        scope: StockTakeScope.column,
        locationId: 7,
        note: '  Kiểm cuối tháng  ',
      );

      expect(id, 42);
      final body = client.calls.single.body!;
      expect(client.calls.single.path, '/api/v1/stocktakes');
      expect(body['warehouseId'], 3);
      expect(body['scopeType'], 'COLUMN');
      expect(body['locationId'], 7);
      expect(body['note'], 'Kiểm cuối tháng');
      // Client KHÔNG được tự bịa tồn kho — danh sách dòng do backend chụp.
      expect(body['stockTakeItems'], isEmpty);
      // 0 = để backend tự gán trạng thái Nháp theo Code, không hard-code Id.
      expect(body['stockTakeStatusId'], 0);
    });

    test('only sends the scope field that matches the chosen scope', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'resources': {'id': '11'},
        },
      );

      final id = await ApiStockTakeRepository(apiClient: client).create(
        warehouseId: 3,
        scope: StockTakeScope.zone,
        zoneName: 'Khu A',
      );

      expect(id, 11);
      final body = client.calls.single.body!;
      expect(body['scopeType'], 'ZONE');
      expect(body['zoneName'], 'Khu A');
      expect(body.containsKey('locationId'), isFalse);
    });
  });

  group('ApiStockTakeRepository.saveCounts', () {
    test('sends the per-bag result of every line', () async {
      final client = FakeApiClient(onPut: (_, __, ___) async => {'isSucceeded': true});
      final line = StockTakeLine(
        id: 90,
        systemQuantity: 100,
        systemBagCount: 2,
        lotCode: 'LOT-A',
        bags: [
          StockTakeBag(
            id: 1,
            paddyLotBagId: 11,
            bagNo: 1,
            systemWeightKg: 50,
            pickSequence: 1,
            restowSequence: 2,
            counted: true,
            scannedByQr: true,
            countedWeightKg: 49.4,
          ),
          StockTakeBag(
            id: 2,
            paddyLotBagId: 22,
            bagNo: 2,
            systemWeightKg: 50,
            pickSequence: 2,
            restowSequence: 1,
          ),
        ],
      )..varianceReason = 'Thiếu 1 bao';

      await ApiStockTakeRepository(apiClient: client)
          .saveCounts(5, [line], note: '  Ca chiều  ');

      final call = client.calls.single;
      expect(call.method, 'PUT');
      expect(call.path, '/api/v1/stocktakes/5/counts');
      expect(call.body?['note'], 'Ca chiều');

      final items = call.body?['items'] as List<dynamic>;
      final item = items.single as Map<String, dynamic>;
      expect(item['id'], 90);
      // Dòng theo bao không gửi tổng kg — backend tính lại từ chính các bao.
      expect(item.containsKey('actualQuantity'), isFalse);
      expect(item['varianceReason'], 'Thiếu 1 bao');
      final bags = item['bags'] as List<dynamic>;
      expect(bags, hasLength(2));
      expect((bags.first as Map<String, dynamic>)['countedWeightKg'], 49.4);
      expect((bags.last as Map<String, dynamic>)['counted'], isFalse);
    });
  });

  group('ApiStockTakeRepository.submit', () {
    test('puts to the submit endpoint with a trimmed note', () async {
      final client = FakeApiClient(onPut: (_, __, ___) async => {'isSucceeded': true});

      await ApiStockTakeRepository(apiClient: client).submit(8, note: '  Xong  ');

      expect(client.calls.single.path, '/api/v1/stocktakes/8/submit');
      expect(client.calls.single.body?['note'], 'Xong');
    });
  });

  group('ApiStockTakeRepository.scanBag', () {
    test('asks the backend whether the scanned bag belongs to the slip',
        () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'resources': {
            'matched': true,
            'message': 'Đã đếm bao',
            'reason': 'OK',
            'stockTakeItemId': 90,
            'stockTakeItemBagId': 5,
            'paddyLotBagId': 55,
            'bagNo': 3,
            'lotCode': 'LOT-A',
          },
        },
      );

      final result =
          await ApiStockTakeRepository(apiClient: client).scanBag(4, '  BAG-0001  ');

      expect(client.calls.single.path, '/api/v1/stocktakes/4/scan-bag');
      expect(client.calls.single.body?['qrCode'], 'BAG-0001');
      expect(result.matched, isTrue);
      expect(result.bagId, 5);
      expect(result.paddyLotBagId, 55);
      expect(result.stockTakeItemId, 90);
    });

    test('sends the weighed kilograms captured at scan time', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'resources': {'matched': true, 'reason': 'OK', 'message': 'ok'},
        },
      );

      await ApiStockTakeRepository(apiClient: client)
          .scanBag(4, 'BAG-0001', countedWeightKg: 49.2);

      expect(client.calls.single.body?['countedWeightKg'], 49.2);
    });

    test('an empty payload is reported as "not matched", never as counted',
        () async {
      final client = FakeApiClient(onPost: (_, __, ___) async => {});

      final result =
          await ApiStockTakeRepository(apiClient: client).scanBag(4, 'BAG-0001');

      expect(result.matched, isFalse);
      expect(result.bagId, isNull);
    });
  });

  group('ApiStockTakeRepository.getLocations', () {
    test('keeps only the locations of the selected warehouse', () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {
          'resources': [
            {'id': 1, 'warehouseId': 3, 'zoneName': 'Khu A', 'slotCode': 'A-01'},
            {'id': 2, 'warehouseId': 9, 'zoneName': 'Khu B', 'slotCode': 'B-01'},
            {'id': 0, 'warehouseId': 3, 'zoneName': 'Khu C'},
          ],
        },
      );

      final options =
          await ApiStockTakeRepository(apiClient: client).getLocations(3);

      expect(options, hasLength(1));
      expect(options.single.id, 1);
      expect(options.single.label, 'Khu A / A-01');
    });

    test('missing permission on the location catalog still allows a stocktake',
        () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async =>
            throw const ApiException(message: 'Không đủ quyền', statusCode: 403),
      );

      expect(
        await ApiStockTakeRepository(apiClient: client).getLocations(3),
        isEmpty,
      );
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
