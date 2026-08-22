import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/routes/app_routes.dart';
import 'package:stocklite/core/screens/permission_denied_screen.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/auth/presentation/screens/login_screen.dart';
import 'package:stocklite/features/scan/presentation/screens/scan_qr_screen.dart';

void main() {
  tearDown(() {
    AuthSessionStore.current = null;
  });

  testWidgets('home route fails closed when session is null', (tester) async {
    AuthSessionStore.current = null;

    await tester.pumpWidget(
      MaterialApp(initialRoute: AppRoutes.home, routes: AppRoutes.routes),
    );
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('QR route denies CREATE-only permission before scanner mounts',
      (tester) async {
    AuthSessionStore.current = _session(
      const {'CREATE'},
      menuCode: 'PRODUCT_VARIANTS',
    );

    await tester.pumpWidget(
      MaterialApp(initialRoute: AppRoutes.scanQr, routes: AppRoutes.routes),
    );
    await tester.pump();

    expect(find.byType(PermissionDeniedScreen), findsOneWidget);
    expect(find.byType(ScanQrScreen), findsNothing);
  });

  testWidgets('QR route opens with PRODUCT_VARIANTS READ', (tester) async {
    AuthSessionStore.current = _session(
      const {'READ'},
      menuCode: 'PRODUCT_VARIANTS',
    );

    await tester.pumpWidget(
      MaterialApp(initialRoute: AppRoutes.scanQr, routes: AppRoutes.routes),
    );
    await tester.pump();

    expect(find.byType(ScanQrScreen), findsOneWidget);
    expect(find.byType(PermissionDeniedScreen), findsNothing);
  });

  testWidgets('milling route opens with explicit READ', (tester) async {
    AuthSessionStore.current = _session(
      const {'READ'},
      menuCode: 'MILLING_ORDERS',
    );

    await tester.pumpWidget(
      MaterialApp(initialRoute: AppRoutes.milling, routes: AppRoutes.routes),
    );
    await tester.pump();

    expect(find.byType(PermissionDeniedScreen), findsNothing);
  });
}

AuthSession _session(Set<String> actions, {required String menuCode}) {
  return AuthSession(
    accessToken: 'token',
    refreshToken: 'refresh',
    user: AuthUser(
      id: 10,
      fullName: 'Test User',
      email: 'test@stocklite.local',
      permissions: [
        UserPermission(menuId: 1, menuCode: menuCode, actions: actions),
      ],
      menus: [UserMenu(id: 1, code: menuCode, name: menuCode)],
    ),
  );
}
