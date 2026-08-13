import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/paddy_lots/data/paddy_lot_repository.dart';

import 'support/fake_api_client.dart';

AuthSession _session() => const AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: AuthUser(id: 1, fullName: 'Thủ kho', email: 'thukho@example.com'),
    );

Map<String, dynamic> _pagedResponse(List<Map<String, dynamic>> rows) => {
      'isSucceeded': true,
      'resources': {
        'draw': 1,
        'recordsTotal': 120,
        'recordsFiltered': rows.length,
        'data': rows,
      },
    };

const _row = <String, dynamic>{
  'id': 5,
  'lotCode': 'LOT-005',
  'lotType': 'PADDY',
  'productVariantId': 3,
  'sku': 'LUA-OM18',
  'productVariantName': 'Lúa OM18',
  'statusId': 2,
  'statusName': 'Sẵn sàng',
  'warehouseId': 1,
  'warehouseName': 'Kho A',
  'initialWeightKg': 1000,
  'remainingWeightKg': 250.5,
};

void main() {
  setUp(() => AuthSessionStore.current = _session());
  tearDown(() => AuthSessionStore.current = null);

  group('ApiPaddyLotRepository.searchLots', () {
    test('gọi endpoint lọc nâng cao thay vì GET danh sách thường', () async {
      final client = FakeApiClient(
        onPost: (path, body, token) async => _pagedResponse([_row]),
      );

      await ApiPaddyLotRepository(apiClient: client).searchLots();

      // GET /paddy-lots không include navigation nên thiếu warehouseName và
      // statusName — phải dùng paged-advanced.
      expect(client.calls.single.method, 'POST');
      expect(client.calls.single.path, '/api/v1/paddy-lots/paged-advanced');
    });

    test('đưa bộ lọc vào đúng cột mà backend đọc', () async {
      Map<String, dynamic>? captured;
      final client = FakeApiClient(
        onPost: (path, body, token) async {
          captured = body;
          return _pagedResponse([_row]);
        },
      );

      await ApiPaddyLotRepository(apiClient: client).searchLots(
        filter: const PaddyLotFilter(
          keyword: '  LOT-005  ',
          lotType: 'PADDY',
          warehouseId: 7,
          statusId: 3,
        ),
      );

      expect(captured!['search'], {'value': 'LOT-005', 'regex': false});

      final columns = (captured!['columns'] as List).cast<Map>();
      String searchOf(String data) => columns
          .firstWhere((c) => c['data'] == data)['search']['value'] as String;

      expect(searchOf('lotType'), 'PADDY');
      expect(searchOf('warehouseId'), '7');
      expect(searchOf('statusId'), '3');
    });

    test('bộ lọc rỗng thì gửi chuỗi rỗng, không gửi "null"', () async {
      Map<String, dynamic>? captured;
      final client = FakeApiClient(
        onPost: (path, body, token) async {
          captured = body;
          return _pagedResponse([_row]);
        },
      );

      await ApiPaddyLotRepository(apiClient: client).searchLots();

      final columns = (captured!['columns'] as List).cast<Map>();
      for (final column in columns) {
        expect(column['search']['value'], '');
      }
      expect(captured!['search'], {'value': '', 'regex': false});
    });

    test('map được kho và trạng thái mà API cũ trả về null', () async {
      final client = FakeApiClient(
        onPost: (path, body, token) async => _pagedResponse([_row]),
      );

      final page = await ApiPaddyLotRepository(apiClient: client).searchLots();

      expect(page.lots.single.warehouseName, 'Kho A');
      expect(page.lots.single.statusName, 'Sẵn sàng');
      expect(page.lots.single.remainingWeightKg, 250.5);
      expect(page.totalRecords, 1);
    });

    test('bỏ các dòng thiếu id hoặc mã lô', () async {
      final client = FakeApiClient(
        onPost: (path, body, token) async => _pagedResponse([
          _row,
          const {'id': 0, 'lotCode': 'LOT-X'},
          const {'id': 9, 'lotCode': ''},
        ]),
      );

      final page = await ApiPaddyLotRepository(apiClient: client).searchLots();

      expect(page.lots, hasLength(1));
    });
  });

  group('Nguồn dropdown lọc', () {
    test('đọc danh mục kho và trạng thái lô, sắp theo tên', () async {
      final client = FakeApiClient(
        onGet: (path, query, token) async => {
          'isSucceeded': true,
          'resources': path.contains('warehouse')
              ? [
                  {'id': 2, 'name': 'Kho B'},
                  {'id': 1, 'name': 'Kho A'},
                ]
              : [
                  {'id': 5, 'name': 'Cách ly'},
                  {'id': 4, 'name': 'Sẵn sàng'},
                ],
        },
      );
      final repository = ApiPaddyLotRepository(apiClient: client);

      final warehouses = await repository.getWarehouseOptions();
      final statuses = await repository.getStatusOptions();

      expect(warehouses.map((w) => w.name), ['Kho A', 'Kho B']);
      expect(statuses.map((s) => s.name), ['Cách ly', 'Sẵn sàng']);
    });

    test('thiếu quyền đọc danh mục thì trả rỗng chứ không làm hỏng màn', () async {
      final client = FakeApiClient(
        onGet: (path, query, token) async =>
            {'isSucceeded': false, 'message': 'Không có quyền'},
      );

      final options =
          await ApiPaddyLotRepository(apiClient: client).getWarehouseOptions();

      expect(options, isEmpty);
    });
  });

  group('PaddyLotFilter', () {
    test('clear* xoá đúng tiêu chí thay vì giữ giá trị cũ', () {
      const filter =
          PaddyLotFilter(lotType: 'RICE', warehouseId: 2, statusId: 3);

      expect(filter.copyWith(clearLotType: true).lotType, isNull);
      expect(filter.copyWith(clearWarehouse: true).warehouseId, isNull);
      expect(filter.copyWith(clearStatus: true).statusId, isNull);
      expect(filter.copyWith(clearLotType: true).warehouseId, 2);
    });

    test('isEmpty bỏ qua từ khoá chỉ có khoảng trắng', () {
      expect(const PaddyLotFilter().isEmpty, isTrue);
      expect(const PaddyLotFilter(keyword: '   ').isEmpty, isTrue);
      expect(const PaddyLotFilter(keyword: 'LOT').isEmpty, isFalse);
      expect(const PaddyLotFilter(statusId: 1).isEmpty, isFalse);
    });
  });
}
