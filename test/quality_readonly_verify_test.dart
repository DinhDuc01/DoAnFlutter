import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/quality_inspection/data/quality_inspection_readonly_repository.dart';
import 'package:stocklite/features/quality_inspection/models/quality_inspection_readonly.dart';
import 'package:stocklite/features/quality_inspection/presentation/screens/quality_inspection_readonly_screen.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'support/fake_api_client.dart';

void main() {
  setUp(() {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'quality-test-token',
      refreshToken: 'refresh',
      user: AuthUser(id: 1, fullName: 'Tester', email: 'test@example.com'),
    );
  });
  tearDown(() => AuthSessionStore.current = null);

  test('sends paging/search/filter/sort and parses DataTables page', () async {
    final client = FakeApiClient(onPost: (_, body, token) async {
      expect(token, 'quality-test-token');
      expect(body!['start'], 20);
      expect(body['length'], 20);
      expect((body['search'] as Map)['value'], 'LOT-02');
      expect((body['order'] as List).single['dir'], 'desc');
      expect((body['columns'] as List)[4]['search']['value'], 'true');
      return {
        'isSucceeded': true,
        'resources': {
          'data': [
            {
              'id': 2,
              'paddyLotId': 4,
              'lotCode': 'LOT-02',
              'passedInspection': true,
              'inspectedAt': '2026-08-02T00:00:00Z',
            },
          ],
          'recordsTotal': 41,
          'recordsFiltered': 21,
        },
      };
    });

    final page = await ApiQualityInspectionReadOnlyRepository(apiClient: client)
        .loadPage(start: 20, length: 20, search: 'LOT-02', passedInspection: true);
    expect(page.items.single.lotCode, 'LOT-02');
    expect(page.recordsTotal, 41);
    expect(page.recordsFiltered, 21);
    expect(client.calls.single.method, 'POST');
    expect(client.calls.single.path, '/api/v1/quality-inspections/paged-advanced');
  });

  test('parses nullable detail, lot and newest-first history without mutation', () async {
    final client = FakeApiClient(onGet: (path, _, token) async {
      expect(token, 'quality-test-token');
      if (path.contains('/by-lot/')) {
        return {'isSucceeded': true, 'resources': [
          {'id': 1, 'inspectedAt': '2026-07-01T00:00:00Z', 'passedInspection': false},
          {'id': 2, 'inspectedAt': '2026-08-01T00:00:00Z', 'passedInspection': true},
        ]};
      }
      if (path.contains('/paddy-lots/')) {
        return {'isSucceeded': true, 'resources': {'lotCode': 'LOT-01', 'warehouseName': 'Kho A'}};
      }
      return {'isSucceeded': true, 'resources': {'id': 9, 'paddyLotId': 3}};
    });
    final repo = ApiQualityInspectionReadOnlyRepository(apiClient: client);
    final detail = await repo.getDetail(9);
    final lot = await repo.getLot(3);
    final history = await repo.getHistory(3);
    expect(detail.lotCode, isNull);
    expect(detail.moisturePercent, isNull);
    expect(lot.text('warehouseName'), 'Kho A');
    expect(history.first.inspectionId, 2);
    expect(client.calls.every((call) => call.method == 'GET'), isTrue);
  });

  testWidgets('renders card, filter, pagination and read-only detail', (tester) async {
    final repo = _FakeQualityRepository();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: QualityInspectionReadOnlyScreen(repository: repo))));
    await tester.pumpAndSettle();
    expect(find.text('LOT-01'), findsOneWidget);
    expect(find.text('Đạt'), findsOneWidget);
    expect(find.text('Tạo'), findsNothing);
    expect(find.text('Sửa'), findsNothing);
    expect(find.text('Xóa'), findsNothing);
    expect(find.text('Chốt'), findsNothing);
    await tester.tap(find.text('LOT-01'));
    await tester.pumpAndSettle();
    expect(find.text('Kết quả kiểm định'), findsOneWidget);
    expect(repo.mutations, 0);
  });
}

class _FakeQualityRepository implements QualityInspectionReadOnlyRepository {
  int mutations = 0;
  final item = QualityInspectionReadOnly(
    inspectionId: 1, paddyLotId: 3, lotCode: 'LOT-01', passedInspection: true,
    inspectedAt: DateTime(2026, 8, 1), moisturePercent: 13,
  );
  @override
  Future<QualityInspectionPage> loadPage({required int start, required int length, String search = '', bool? passedInspection}) async => QualityInspectionPage(items: [item], recordsTotal: 1, recordsFiltered: 1);
  @override
  Future<QualityInspectionReadOnly> getDetail(int id) async => item;
  @override
  Future<List<QualityInspectionReadOnly>> getHistory(int paddyLotId) async => [item];
  @override
  Future<QualityLotSummary> getLot(int paddyLotId) async => const QualityLotSummary(values: {'warehouseName': 'Kho A'});
}
