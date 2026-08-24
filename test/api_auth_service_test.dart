import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/api/api_client.dart';
import 'package:stocklite/features/auth/data/api_auth_service.dart';
import 'package:stocklite/features/auth/data/auth_service.dart';

import 'support/fake_api_client.dart';

void main() {
  test('rejects an empty username without calling the API', () async {
    final client = FakeApiClient();
    final service = ApiAuthService(apiClient: client);

    await expectLater(
      service.login(email: '   ', password: 'password'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Vui lòng nhập tài khoản và mật khẩu',
        ),
      ),
    );
    expect(client.calls, isEmpty);
  });

  test('rejects an empty password without calling the API', () async {
    final client = FakeApiClient();
    final service = ApiAuthService(apiClient: client);

    await expectLater(
      service.login(email: 'admin', password: ''),
      throwsA(isA<AuthException>()),
    );
    expect(client.calls, isEmpty);
  });

  test('parses a successful login session and trims username', () async {
    final client = FakeApiClient(
      onPost: (path, body, token) async => {
        'isSucceeded': true,
        'resources': {
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'userInfo': {
            'id': 7,
            'fullName': 'Admin User',
            'email': 'admin@example.com',
            'avatarUrl': 'avatar.png',
          },
        },
      },
    );

    final session = await ApiAuthService(apiClient: client).login(
      email: ' admin ',
      password: 'secret',
    );

    expect(session.accessToken, 'access');
    expect(session.refreshToken, 'refresh');
    expect(session.user.id, 7);
    expect(session.user.fullName, 'Admin User');
    expect(session.user.avatarUrl, 'avatar.png');
    // Business users must use the login contract that embeds RoleIds in JWT.
    // Role-backed endpoints (for example the inbound bag putaway planner) deny
    // a token from /auth/login even when /auth/me/session has permissions.
    expect(client.calls.single.path, '/api/v1/auth/admin/login');
    expect(client.calls.single.body, {
      'username': 'admin',
      'password': 'secret',
    });
  });

  test('rejects a successful response without token values', () async {
    final client = FakeApiClient(
      onPost: (_, __, ___) async => {
        'isSucceeded': true,
        'resources': {
          'accessToken': '',
          'refreshToken': '',
          'userInfo': {'id': 1, 'fullName': 'User'},
        },
      },
    );

    await expectLater(
      ApiAuthService(apiClient: client).login(
        email: 'warehouse-user',
        password: 'secret',
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'API đăng nhập không trả đủ thông tin token phiên',
        ),
      ),
    );
  });

  test('uses backend failure message', () async {
    final client = FakeApiClient(
      onPost: (_, __, ___) async => {
        'isSucceeded': false,
        'message': 'Sai thông tin đăng nhập',
      },
    );

    await expectLater(
      ApiAuthService(apiClient: client).login(
        email: 'admin',
        password: 'wrong',
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Sai thông tin đăng nhập',
        ),
      ),
    );
  });

  test('rejects successful response without session resources', () async {
    final client = FakeApiClient(
      onPost: (_, __, ___) async => {'isSucceeded': true},
    );

    await expectLater(
      ApiAuthService(apiClient: client).login(
        email: 'admin',
        password: 'secret',
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'API đăng nhập không trả dữ liệu phiên',
        ),
      ),
    );
  });

  test('rejects successful response without user information', () async {
    final client = FakeApiClient(
      onPost: (_, __, ___) async => {
        'isSucceeded': true,
        'resources': {'accessToken': 'token'},
      },
    );

    await expectLater(
      ApiAuthService(apiClient: client).login(
        email: 'admin',
        password: 'secret',
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'API đăng nhập không trả thông tin người dùng',
        ),
      ),
    );
  });

  test('converts ApiException into AuthException', () async {
    final client = FakeApiClient(
      onPost: (_, __, ___) async =>
          throw const ApiException(message: 'API unavailable'),
    );

    await expectLater(
      ApiAuthService(apiClient: client).login(
        email: 'admin',
        password: 'secret',
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'API unavailable',
        ),
      ),
    );
  });

  test('wraps unexpected errors with authentication context', () async {
    final client = FakeApiClient(
      onPost: (_, __, ___) async => throw StateError('broken parser'),
    );

    await expectLater(
      ApiAuthService(apiClient: client).login(
        email: 'admin',
        password: 'secret',
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          contains('Không đăng nhập được'),
        ),
      ),
    );
  });
}
