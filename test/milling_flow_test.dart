import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/routes/app_routes.dart';
import 'package:stocklite/features/milling/data/milling_repository.dart';
import 'package:stocklite/features/milling/presentation/screens/milling_preparation_screen.dart';

void main() {
  test('mock milling order calculates rice, bran and yield totals', () async {
    final order = await MockMillingRepository().getActiveOrder();

    expect(order.totalRiceKg, 250);
    expect(order.totalBranKg, 99.5);
    expect(order.riceYieldPercent, 5);
  });

  testWidgets('milling flow navigates through all weighing steps',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MillingPreparationScreen(repository: MockMillingRepository()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Lệnh xay xát'), findsOneWidget);
    expect(find.textContaining('MO-2026-021'), findsOneWidget);

    await tester.tap(find.textContaining('MO-2026-021').first);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết lệnh xay'), findsOneWidget);

    await tester.tap(find.text('Tiếp tục cân/kết quả'));
    await tester.pumpAndSettle();
    expect(find.text('Cân gạo sau xay'), findsOneWidget);
    expect(find.text('10 bao'), findsOneWidget);

    await tester.tap(find.text('Tiếp tục cân cám'));
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();
    expect(find.text('Cân cám sau xay'), findsOneWidget);
    expect(find.text('5 bao'), findsOneWidget);

    await tester.tap(find.text('Tiếp tục cân tấm'));
    await tester.pumpAndSettle();
    expect(find.text('Cân tấm sau xay'), findsOneWidget);

    await tester.tap(find.text('Bỏ qua tấm'));
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận kết quả xay'), findsOneWidget);
    expect(find.text('5.0%'), findsOneWidget);
  });

  testWidgets('home milling shortcut opens the dedicated milling route',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: AppRoutes.home,
        routes: {
          ...AppRoutes.routes,
          AppRoutes.milling: (_) => MillingPreparationScreen(
                repository: MockMillingRepository(),
              ),
        },
      ),
    );
    await tester.pump();

    final millingShortcut = find.ancestor(
      of: find.text('Xay xát'),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(millingShortcut);
    await tester.pump();
    await tester.tap(millingShortcut);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Lệnh xay xát'), findsOneWidget);
  });
}
