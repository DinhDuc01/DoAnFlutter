import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/routes/app_routes.dart';
import 'package:stocklite/features/auth/data/auth_service.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/auth/presentation/screens/login_screen.dart';

void main() {
  tearDown(() {
    AuthSessionStore.current = null;
  });

  testWidgets('shows an error when the username is incorrect', (tester) async {
    final authService = _RejectingAuthService('Tài khoản không tồn tại');

    await _pumpLoginScreen(tester, authService);
    await tester.enterText(
      find.byKey(const ValueKey('login_username')),
      'wrong-user',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login_password')),
      'Abc@123456',
    );
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Tài khoản không tồn tại'), findsOneWidget);
    expect(authService.receivedUsername, 'wrong-user');
    expect(authService.receivedPassword, 'Abc@123456');
    expect(AuthSessionStore.current, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('shows an error when the password is incorrect', (tester) async {
    final authService = _RejectingAuthService('Mật khẩu không chính xác');

    await _pumpLoginScreen(tester, authService);
    await tester.enterText(
      find.byKey(const ValueKey('login_username')),
      'admin',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login_password')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Mật khẩu không chính xác'), findsOneWidget);
    expect(authService.receivedUsername, 'admin');
    expect(authService.receivedPassword, 'wrong-password');
    expect(AuthSessionStore.current, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('stores the session and opens home after a successful login',
      (tester) async {
    const session = AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      user: AuthUser(
        id: 1,
        fullName: 'Quản trị viên',
        email: 'admin@example.com',
      ),
    );
    final authService = _AcceptingAuthService(session);

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.home: (_) => const Scaffold(body: Text('Home screen')),
        },
        home: LoginScreen(authService: authService),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('login_username')),
      'admin',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login_password')),
      'Abc@123456',
    );
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    await tester.pumpAndSettle();

    expect(authService.receivedUsername, 'admin');
    expect(authService.receivedPassword, 'Abc@123456');
    expect(AuthSessionStore.current, same(session));
    expect(find.text('Home screen'), findsOneWidget);
  });
}

Future<void> _pumpLoginScreen(
  WidgetTester tester,
  AuthService authService,
) async {
  await tester.pumpWidget(
    MaterialApp(home: LoginScreen(authService: authService)),
  );
}

class _RejectingAuthService implements AuthService {
  _RejectingAuthService(this.message);

  final String message;
  String? receivedUsername;
  String? receivedPassword;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    receivedUsername = email;
    receivedPassword = password;
    throw AuthException(message);
  }

  @override
  Future<AuthSession> refresh(AuthSession session) async => session;
}

class _AcceptingAuthService implements AuthService {
  _AcceptingAuthService(this.session);

  final AuthSession session;
  String? receivedUsername;
  String? receivedPassword;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    receivedUsername = email;
    receivedPassword = password;
    return session;
  }

  @override
  Future<AuthSession> refresh(AuthSession session) async => session;
}
