import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/routes/app_routes.dart';
import 'package:stocklite/features/account/presentation/widgets/account_tab.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';

void main() {
  tearDown(() {
    AuthSessionStore.current = null;
  });

  testWidgets('account tab displays the user returned by the login API',
      (tester) async {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'test-token',
      refreshToken: 'test-refresh-token',
      user: AuthUser(
        id: 42,
        fullName: 'Nguyễn Minh Khang',
        email: 'khang@example.com',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AccountTab())),
    );

    expect(find.text('Nguyễn Minh Khang'), findsOneWidget);
    expect(find.text('khang@example.com'), findsOneWidget);
    expect(find.text('N'), findsOneWidget);
    expect(find.text('Chủ kho Tuấn'), findsNothing);
  });

  testWidgets('account tab displays an error when the session is missing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.login: (_) => const Scaffold(body: Text('Login screen')),
        },
        home: Scaffold(
          body: AccountTab(logout: (_) async {}),
        ),
      ),
    );

    expect(find.text('Đã xảy ra lỗi'), findsOneWidget);
    expect(
      find.text(
        'Không thể tải dữ liệu. Vui lòng thử lại hoặc liên hệ quản trị viên.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Login screen'), findsOneWidget);
  });

  testWidgets('account tab uses fallback text for an incomplete user profile',
      (tester) async {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'test-token',
      refreshToken: 'test-refresh-token',
      user: AuthUser(id: 42, fullName: '   ', email: ''),
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AccountTab())),
    );

    expect(find.text('Người dùng'), findsOneWidget);
    expect(find.text('Chưa có email'), findsOneWidget);
    expect(find.text('N'), findsOneWidget);
  });

  testWidgets('synchronize action explains that data comes from the API',
      (tester) async {
    AuthSessionStore.current = _testSession();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AccountTab())),
    );
    await tester.tap(find.text('Đồng bộ dữ liệu'));
    await tester.pump();

    expect(
      find.text('Dữ liệu đang được tải trực tiếp từ API.'),
      findsOneWidget,
    );
  });

  testWidgets('logout clears the session and returns to login', (tester) async {
    AuthSessionStore.current = _testSession();

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.login: (_) => const Scaffold(body: Text('Login screen')),
        },
        home: Scaffold(body: AccountTab(logout: (_) async {})),
      ),
    );

    await tester.ensureVisible(find.text('Đăng xuất'));
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();

    expect(AuthSessionStore.current, isNull);
    expect(find.text('Login screen'), findsOneWidget);
  });
}

AuthSession _testSession() {
  return const AuthSession(
    accessToken: 'test-token',
    refreshToken: 'test-refresh-token',
    user: AuthUser(
      id: 42,
      fullName: 'Nguyễn Minh Khang',
      email: 'khang@example.com',
    ),
  );
}
