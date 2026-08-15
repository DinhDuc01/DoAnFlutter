import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/kho/data/stock_take_repository.dart';
import 'support/fake_api_client.dart';

void main() {
  setUp(() {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'token', refreshToken: 'refresh',
      user: AuthUser(id: 1, fullName: 'Approver', email: 'approver@test.local', permissions: [
        UserPermission(menuId: 1, menuCode: 'STOCKTAKE', actions: {'APPROVE', 'DELETE'}),
      ]),
    );
  });
  tearDown(() => AuthSessionStore.current = null);

  test('approve uses endpoint, body and bearer token', () async {
    final client = FakeApiClient(onPut: (_, __, ___) async => {'isSucceeded': true});
    await ApiStockTakeRepository(apiClient: client).approve(7, approveNote: '  OK  ');
    expect(client.calls.single.path, '/api/v1/stocktakes/7/approve');
    expect(client.calls.single.token, 'token');
    expect(client.calls.single.body, {'approveNote': 'OK'});
  });

  test('reject uses endpoint and required reason', () async {
    final client = FakeApiClient(onPut: (_, __, ___) async => {'isSucceeded': true});
    await ApiStockTakeRepository(apiClient: client).reject(7, reason: 'Sai số đếm');
    expect(client.calls.single.path, '/api/v1/stocktakes/7/reject');
    expect(client.calls.single.body, {'reason': 'Sai số đếm'});
  });

  test('delete uses endpoint and bearer token', () async {
    final client = FakeApiClient(onDelete: (_, __, ___) async => {'isSucceeded': true});
    await ApiStockTakeRepository(apiClient: client).delete(7);
    expect(client.calls.single.method, 'DELETE');
    expect(client.calls.single.path, '/api/v1/stocktakes/7');
    expect(client.calls.single.token, 'token');
  });

  test('failed mutation throws and does not retry', () async {
    final client = FakeApiClient(onPut: (_, __, ___) async => {'isSucceeded': false, 'message': 'Conflict'});
    await expectLater(ApiStockTakeRepository(apiClient: client).approve(7), throwsA(isA<StockTakeException>()));
    expect(client.calls, hasLength(1));
  });
}
