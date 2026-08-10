import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/routes/app_routes.dart';
import 'package:stocklite/features/home/presentation/widgets/home_today_tab.dart';

void main() {
  testWidgets('home hides quality inspection and keeps stocktake route',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: HomeTodayTab()),
        routes: {
          AppRoutes.stocktake: (_) =>
              const Scaffold(body: Text('STOCKTAKE_ROUTE')),
        },
      ),
    );

    expect(find.text('Kiểm chất'), findsNothing);
    await tester.ensureVisible(find.text('Kiểm kê'));
    await tester.tap(find.text('Kiểm kê'));
    await tester.pumpAndSettle();
    expect(find.text('STOCKTAKE_ROUTE'), findsOneWidget);
  });
}
