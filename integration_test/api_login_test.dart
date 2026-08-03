import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stocklite/features/home/presentation/screens/home_screen.dart';
import 'package:stocklite/main.dart' as app;

const username = String.fromEnvironment('TEST_USERNAME');
const password = String.fromEnvironment('TEST_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'logs in through the configured backend',
    (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('login_username')),
        username,
      );
      await tester.enterText(
        find.byKey(const ValueKey('login_password')),
        password,
      );
      await tester.tap(find.byKey(const ValueKey('login_submit')));

      for (var second = 0; second < 90; second++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.byType(HomeScreen).evaluate().isNotEmpty) break;
      }

      expect(find.byType(HomeScreen), findsOneWidget);
    },
    skip: username.isEmpty || password.isEmpty,
  );
}
