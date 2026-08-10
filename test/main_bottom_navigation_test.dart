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
      'Bán',
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

    await tester.tap(find.text('Bán'));

    expect(selectedIndex, 3);
  });
}
