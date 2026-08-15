import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/home/presentation/widgets/main_bottom_navigation.dart';

void main() {
  testWidgets('shows all six main application tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MainBottomNavigation(
            currentIndex: 1,
            onTap: (_) {},
          ),
        ),
      ),
    );

    for (final label in [
      'Trang chủ',
      'Thu mua',
      'Kho',
      'Xuất kho',
      'Thông báo',
      'Tôi',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      1,
    );
  });

  testWidgets('reports the selected main tab', (tester) async {
    int? selectedIndex;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MainBottomNavigation(
            currentIndex: 1,
            onTap: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Xuất kho'));

    expect(selectedIndex, 3);
  });

  testWidgets('hides business tabs omitted by permission filtering',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MainBottomNavigation(
            currentIndex: 0,
            sections: const [
              HomeSection.home,
              HomeSection.notifications,
              HomeSection.account,
            ],
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Tôi'), findsOneWidget);
    expect(find.text('Thu mua'), findsNothing);
    expect(find.text('Kho'), findsNothing);
    expect(find.text('Xuất kho'), findsNothing);
  });
}
