import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/app/app.dart';

void main() {
  testWidgets('shows Lua gao Tuan May login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StockLiteApp());

    expect(find.text('Lúa gạo Tuấn Mây'), findsOneWidget);
    expect(
        find.text(
            'Công cụ hiện trường cho thu mua, kho, giao hàng và kiểm kê lúa gạo.'),
        findsOneWidget);
    final username = tester.widget<TextField>(
      find.byKey(const ValueKey('login_username')),
    );
    final password = tester.widget<TextField>(
      find.byKey(const ValueKey('login_password')),
    );
    expect(username.controller?.text, isEmpty);
    expect(password.controller?.text, isEmpty);
    expect(find.text('Đăng nhập'), findsWidgets);
  });
}
