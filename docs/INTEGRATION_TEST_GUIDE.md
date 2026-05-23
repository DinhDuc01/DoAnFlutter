# Hướng dẫn Integration Test cho StockLite

## 1. Integration test là gì?

Integration test là test tự động chạy app thật hoặc gần thật, rồi tự thao tác như người dùng:

```text
mở app
→ tìm nút
→ bấm nút
→ nhập text
→ chuyển màn
→ kiểm tra kết quả
```

Khác với manual test, tester không cần tự bấm từng bước. Máy sẽ chạy theo kịch bản test đã viết.

## 2. Khi nào dùng integration test?

Dùng cho các luồng quan trọng:

- Đăng nhập
- Từ Home mở Nhập kho
- Xác nhận nhập kho thành công
- Từ Home mở Xuất kho
- Xác nhận xuất kho thành công
- Mở Kiểm kho
- Mở Thông báo
- Mở Tài khoản
- Mở Quét QR

Không nên test mọi chi tiết nhỏ bằng integration test. Những thứ như màu sắc, padding, font size vẫn nên kiểm bằng manual/UI review.

## 3. Cần chuẩn bị gì?

Trong `pubspec.yaml`, thêm dependency test:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

Sau đó chạy:

```powershell
flutter pub get
```

## 4. Tạo thư mục integration test

Tạo thư mục:

```text
integration_test/
```

Ví dụ file đầu tiên:

```text
integration_test/login_flow_test.dart
```

## 5. Ví dụ test đăng nhập đơn giản

File:

```text
integration_test/login_flow_test.dart
```

Code mẫu:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stocklite/app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login mock opens home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const StockLiteApp());
    await tester.pumpAndSettle();

    expect(find.text('StockLite'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);

    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Nhập kho'), findsOneWidget);
    expect(find.text('Xuất kho'), findsOneWidget);
    expect(find.text('Kiểm kho'), findsOneWidget);
  });
}
```

Ý nghĩa:

- Mở app bằng `StockLiteApp`.
- Kiểm tra màn login có `StockLite`.
- Bấm `Đăng nhập`.
- Đợi app chuyển màn.
- Kiểm tra đã vào Home bằng các text trên Home.

## 6. Cách chạy integration test

Trước tiên mở emulator:

```powershell
flutter emulators
flutter emulators --launch Small_Phone
```

Kiểm tra thiết bị:

```powershell
flutter devices
```

Chạy test:

```powershell
flutter test integration_test/login_flow_test.dart
```

Hoặc nếu có nhiều thiết bị:

```powershell
flutter test integration_test/login_flow_test.dart -d emulator-5554
```

## 7. Test flow Nhập kho

Ví dụ sau khi login, mở Nhập kho và xác nhận:

```dart
testWidgets('inbound flow opens success screen', (WidgetTester tester) async {
  await tester.pumpWidget(const StockLiteApp());
  await tester.pumpAndSettle();

  await tester.tap(find.text('Đăng nhập'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Nhập kho'));
  await tester.pumpAndSettle();

  expect(find.text('Phiếu nhập kho'), findsOneWidget);
  expect(find.text('Xác nhận nhập kho'), findsOneWidget);

  await tester.tap(find.text('Xác nhận nhập kho'));
  await tester.pumpAndSettle();

  expect(find.text('Thành công!'), findsOneWidget);
  expect(find.text('Đã nhập kho'), findsOneWidget);
});
```

## 8. Test flow Xuất kho

```dart
testWidgets('outbound flow opens success screen', (WidgetTester tester) async {
  await tester.pumpWidget(const StockLiteApp());
  await tester.pumpAndSettle();

  await tester.tap(find.text('Đăng nhập'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Xuất kho'));
  await tester.pumpAndSettle();

  expect(find.text('Phiếu xuất kho'), findsOneWidget);
  expect(find.text('Xác nhận xuất kho'), findsOneWidget);

  await tester.tap(find.text('Xác nhận xuất kho'));
  await tester.pumpAndSettle();

  expect(find.text('Thành công!'), findsOneWidget);
  expect(find.text('Đã xuất kho'), findsOneWidget);
});
```

## 9. Test mở các màn chính từ Home

```dart
testWidgets('home quick actions open main screens', (WidgetTester tester) async {
  await tester.pumpWidget(const StockLiteApp());
  await tester.pumpAndSettle();

  await tester.tap(find.text('Đăng nhập'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Kiểm kho'));
  await tester.pumpAndSettle();
  expect(find.text('Phiếu kiểm kho'), findsOneWidget);
  await tester.pageBack();
  await tester.pumpAndSettle();

  await tester.tap(find.text('Quét QR'));
  await tester.pumpAndSettle();
  expect(find.text('Quét mã QR'), findsOneWidget);
  await tester.pageBack();
  await tester.pumpAndSettle();

  await tester.tap(find.text('Lịch sử'));
  await tester.pumpAndSettle();
  expect(find.text('Lịch sử thao tác'), findsOneWidget);
});
```

## 10. Nên đặt Key cho widget quan trọng

Tìm bằng text là dễ hiểu, nhưng về lâu dài nên dùng `Key`.

Ví dụ trong code app:

```dart
FilledButton(
  key: const Key('login_button'),
  onPressed: _login,
  child: const Text('Đăng nhập'),
)
```

Trong test:

```dart
await tester.tap(find.byKey(const Key('login_button')));
```

Ưu điểm:

- Text đổi thì test không vỡ.
- Tester/dev dễ tìm đúng widget.
- Phù hợp khi một màn có nhiều nút cùng text.

Các key nên thêm sau này:

```text
login_button
home_inbound_action
home_outbound_action
home_inventory_action
home_scan_action
home_history_action
inbound_confirm_button
outbound_confirm_button
inventory_confirm_button
notifications_mark_all_read_button
account_logout_button
scan_now_button
```

## 11. Cấu trúc integration test nên có

Gợi ý:

```text
integration_test/
  login_flow_test.dart
  warehouse_flow_test.dart
  navigation_flow_test.dart
```

Trong đó:

- `login_flow_test.dart`: chỉ test login.
- `warehouse_flow_test.dart`: nhập kho, xuất kho, kiểm kho.
- `navigation_flow_test.dart`: mở các màn chính.

## 12. Một số lỗi thường gặp

### Không thấy thiết bị

Chạy:

```powershell
flutter devices
```

Nếu không thấy emulator, mở emulator trước:

```powershell
flutter emulators --launch Small_Phone
```

### Test bị treo ở pumpAndSettle

Nguyên nhân thường là app có animation/loading chưa kết thúc.

Có thể thay:

```dart
await tester.pumpAndSettle();
```

bằng:

```dart
await tester.pump(const Duration(seconds: 1));
```

### Không tìm thấy text

Kiểm tra:

- Text có đúng dấu tiếng Việt không.
- Text có nằm ngoài màn hình và cần scroll không.
- Có nhiều widget cùng text không.
- Nên chuyển sang dùng `Key`.

## 13. Quy trình tester dùng integration test

Mỗi lần có build mới:

```powershell
flutter pub get
flutter analyze
flutter test
flutter test integration_test/login_flow_test.dart
```

Nếu có nhiều file:

```powershell
flutter test integration_test
```

Sau đó tester vẫn nên manual test nhanh các màn có thay đổi UI.

## 14. Lộ trình nên làm cho project StockLite

Nên làm theo thứ tự:

```text
1. Thêm integration_test dependency
2. Tạo login_flow_test.dart
3. Thêm key cho nút Đăng nhập
4. Chạy test login
5. Thêm test Nhập kho thành công
6. Thêm test Xuất kho thành công
7. Thêm test mở các màn chính
8. Khi nối API, thêm mock/fake API hoặc test backend staging
```

## 15. Kết luận

Integration test không thay thế manual test hoàn toàn.

Nó phù hợp để tự động kiểm tra các luồng chính:

```text
Login
→ Home
→ Nhập kho
→ Xuất kho
→ Kiểm kho
→ Thông báo
→ Tài khoản
→ Quét QR
```

Với app hiện tại, ví dụ đầu tiên nên làm là `login_flow_test.dart`, vì nó đơn giản và xác nhận app mở đúng flow cơ bản.
