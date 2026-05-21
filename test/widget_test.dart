import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/app/app.dart';

void main() {
  testWidgets('shows StockLite login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const StockLiteApp());

    expect(find.text('StockLite'), findsOneWidget);
    expect(find.text('Ứng dụng quản lý kho tinh gọn'), findsOneWidget);
    expect(find.text('nhanvien@stocklite.vn'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
  });
}
