import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/giao_hang/models/giao_hang_receipt.dart';
import 'package:stocklite/features/giao_hang/presentation/screens/giao_hang_success_screen.dart';

void main() {
  testWidgets('completed delivery opens its full detail screen',
      (tester) async {
    final result = GiaoHangSuccessResult(
      receiptCode: 'GH-001',
      quantity: 4,
      productName: 'Gạo ST25',
      sku: 'ST25-5KG',
      customerName: 'Đại lý An Bình',
      customerPhone: '0901000000',
      customerAddress: 'Cần Thơ',
      warehouseName: 'Kho trung tâm',
      locationCode: 'A-01',
      remainingStock: 16,
      performedBy: 'Nhân viên kho',
      completedAt: DateTime(2026, 7, 19, 9, 30),
      orderId: 15,
      status: 'Chờ xác nhận',
      salesMode: SalesMode.delivery,
      unitSalePrice: 18000,
    );

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(arguments: result),
          builder: (_) => const GiaoHangSuccessScreen(),
        ),
      ),
    );

    expect(find.text('Đã tạo đơn bán'), findsOneWidget);
    await tester.tap(find.text('Xem chi tiết đơn bán'));
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết đơn bán'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Đại lý An Bình'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Đại lý An Bình'), findsOneWidget);
    expect(find.text('Kho trung tâm'), findsOneWidget);
    expect(find.text('16 bao'), findsOneWidget);
  });
}
