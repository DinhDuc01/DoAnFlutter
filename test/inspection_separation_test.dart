import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/routes/app_routes.dart';
import 'package:stocklite/features/home/presentation/widgets/home_today_tab.dart';

void main() {
  testWidgets('quality inspection and stocktake open different routes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: HomeTodayTab()),
        routes: {
          AppRoutes.qualityInspection: (_) =>
              const Scaffold(body: Text('QUALITY_ROUTE')),
          AppRoutes.stocktake: (_) =>
              const Scaffold(body: Text('STOCKTAKE_ROUTE')),
        },
      ),
    );

    await tester.ensureVisible(find.text('Kiểm chất'));
    await tester.tap(find.text('Kiểm chất'));
    await tester.pumpAndSettle();
    expect(find.text('QUALITY_ROUTE'), findsOneWidget);

    Navigator.of(tester.element(find.text('QUALITY_ROUTE'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kiểm kê'));
    await tester.tap(find.text('Kiểm kê'));
    await tester.pumpAndSettle();
    expect(find.text('STOCKTAKE_ROUTE'), findsOneWidget);
  });
}
