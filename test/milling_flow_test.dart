import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/routes/app_routes.dart';
import 'package:stocklite/features/milling/data/milling_repository.dart';
import 'package:stocklite/features/milling/presentation/screens/milling_preparation_screen.dart';
import 'package:stocklite/features/home/presentation/widgets/home_today_tab.dart';

void main() {
  test('mock milling order calculates output totals', () async {
    final order = await MockMillingRepository().getActiveOrder();
    expect(order.totalRiceKg, 250);
    expect(order.totalBranKg, 99.5);
    expect(order.riceYieldPercent, 5);
    expect(order.statusCode, 'MILLING');
  });

  testWidgets('MILLING detail opens the multi-output result screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MillingPreparationScreen(repository: MockMillingRepository()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.textContaining('MO-2026-021').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('milling_enter_output_button')), findsOneWidget);
    expect(find.byKey(const Key('milling_output_section')), findsNothing);
    expect(find.byKey(const Key('milling_weighing_confirm_sticky')), findsNothing);
    await tester.tap(find.byKey(const Key('milling_enter_output_button')));
    await tester.pumpAndSettle();
    expect(find.text('Nhập kết quả xay'), findsOneWidget);
  });

  testWidgets('home milling shortcut opens the dedicated milling route',
      (tester) async {
    final observer = _RouteObserver();
    await tester.pumpWidget(
      MaterialApp(
        home: const HomeTodayTab(),
        navigatorObservers: [observer],
        routes: {
          AppRoutes.milling: (_) => MillingPreparationScreen(
                key: const Key('milling_preparation_screen'),
                repository: MockMillingRepository(),
              ),
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final millingShortcut = find.byKey(const ValueKey(AppRoutes.milling));
    await tester.ensureVisible(millingShortcut);
    await tester.tap(millingShortcut);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(observer.pushedRoutes, contains(AppRoutes.milling));
  });
}

class _RouteObserver extends NavigatorObserver {
  final pushedRoutes = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}
