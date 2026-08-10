import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/api/api_client.dart';
import 'package:stocklite/features/account/data/api_account_repository.dart';
import 'package:stocklite/features/auth/data/api_auth_service.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/scan/data/qr_repository.dart';

import 'support/fake_api_client.dart';

void main() {
  setUp(() => AuthSessionStore.current = _session());
  tearDown(() => AuthSessionStore.current = null);

  test('change password uses the backend PUT contract', () async {
    final client = FakeApiClient(
      onPut: (_, __, ___) async => {'isSucceeded': true},
    );

    await ApiAccountRepository(apiClient: client).changePassword(
      oldPassword: 'OldPass@123',
      newPassword: 'NewPass@123',
      confirmNewPassword: 'NewPass@123',
    );

    expect(client.calls.single.method, 'PUT');
    expect(client.calls.single.path, '/api/v1/user/me/change-password');
    expect(client.calls.single.token, 'access-token');
    expect(client.calls.single.body, {
      'oldPassword': 'OldPass@123',
      'newPassword': 'NewPass@123',
      'confirmNewPassword': 'NewPass@123',
    });
  });

  test('logout sends refresh token and access token', () async {
    final client = FakeApiClient(
      onPost: (_, __, ___) async => {'isSucceeded': true},
    );

    await ApiAuthService(apiClient: client).logout(_session());

    expect(client.calls.single.path, '/api/v1/auth/logout');
    expect(client.calls.single.token, 'access-token');
    expect(client.calls.single.body, {'refreshToken': 'refresh-token'});
  });

  test('QR resolve sends LOOKUP context and maps lot details', () async {
    final client = FakeApiClient(
      onPost: (_, __, ___) async => {
        'isSucceeded': true,
        'resources': {
          'entityType': 'PADDY_LOT',
          'entityId': 12,
          'qrCode': 'QR-LOT-12',
          'displayCode': 'LOT-00012',
          'productVariant': {'id': 9, 'sku': 'GAO-ST25', 'name': 'Gạo ST25'},
          'riceVariety': {'id': 3, 'code': 'ST25', 'name': 'ST25'},
          'status': {'id': 1, 'name': 'Sẵn sàng'},
          'remainingWeightKg': 1250.5,
          'isQuarantined': false,
          'warehouse': {'id': 2, 'code': 'KHO-A', 'name': 'Kho A'},
          'navigationTarget': {'type': 'PADDY_LOT_DETAIL', 'id': 12},
          'validationResult': {'success': true},
        },
      },
    );

    final result =
        await ApiQrRepository(apiClient: client).resolve('QR-LOT-12');

    expect(client.calls.single.path, '/api/v1/qr/resolve');
    expect(client.calls.single.body, {
      'payload': 'QR-LOT-12',
      'context': {
        'operation': 'LOOKUP',
        'referenceId': null,
        'warehouseId': null,
      },
    });
    expect(result.entityId, 12);
    expect(result.productVariantId, 9);
    expect(result.productName, 'Gạo ST25');
    expect(result.remainingWeightKg, 1250.5);
    expect(result.warehouseName, 'Kho A');
  });

  test('QR resolve exposes context validation errors', () async {
    final client = FakeApiClient(
      onPost: (_, __, ___) async => {
        'isSucceeded': true,
        'resources': {
          'entityType': 'PADDY_LOT',
          'entityId': 12,
          'qrCode': 'QR-LOT-12',
          'displayCode': 'LOT-00012',
          'validationResult': {
            'success': false,
            'errorMessage': 'Lô không thuộc kho đang kiểm kê',
          },
        },
      },
    );

    await expectLater(
      ApiQrRepository(apiClient: client).resolve(
        'QR-LOT-12',
        operation: 'STOCKTAKE',
        warehouseId: 3,
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Lô không thuộc kho đang kiểm kê',
        ),
      ),
    );
  });

}

AuthSession _session() {
  return const AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    user: AuthUser(
      id: 7,
      fullName: 'Mobile Tester',
      email: 'mobile@example.com',
    ),
  );
}
