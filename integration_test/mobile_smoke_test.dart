import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stocklite/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile app opens and accepts login input', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    final usernameField = find.byKey(const ValueKey('login_username'));
    final passwordField = find.byKey(const ValueKey('login_password'));
    final submitButton = find.byKey(const ValueKey('login_submit'));

    expect(usernameField, findsOneWidget);
    expect(passwordField, findsOneWidget);
    expect(submitButton, findsOneWidget);

    await tester.enterText(usernameField, 'tester');
    await tester.enterText(passwordField, 'Test@123');
    await tester.pump();

    expect(find.text('tester'), findsOneWidget);
    expect(
      tester.widget<TextField>(passwordField).controller?.text,
      'Test@123',
    );
  });
}
