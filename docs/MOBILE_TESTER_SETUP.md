# Chuẩn bị test StockLite Mobile

## Trạng thái môi trường hiện tại

- Flutter `3.41.9`, Dart `3.11.5`.
- Android SDK `36.1`, license đã được chấp nhận.
- Emulator Android 15: `emulator-5554`.
- Application ID: `com.stocklite.app`.
- API mặc định: `https://backend-do-an-api-new.onrender.com`.
- APK debug: `build/app/outputs/flutter-apk/app-debug.apk`.

Lỗi Chrome và Visual Studio trong `flutter doctor` không ảnh hưởng tới việc test Android.

## Chạy nhanh trên emulator

Mở emulator, sau đó chạy tại thư mục project:

```powershell
.\tool\prepare_mobile_test.ps1
```

Script sẽ tự động:

1. Tải dependency.
2. Build APK debug với backend ngoài.
3. Chọn thiết bị Android đầu tiên được ADB nhận.
4. Cài đè APK bằng `adb install -r`.
5. Xóa log cũ và mở ứng dụng.

Nếu APK vừa được build và chỉ muốn cài lại:

```powershell
.\tool\prepare_mobile_test.ps1 -SkipBuild
```

## Test trên điện thoại Android thật

1. Mở `Cài đặt > Giới thiệu điện thoại` và bấm `Số bản dựng` 7 lần.
2. Mở `Tùy chọn nhà phát triển` và bật `Gỡ lỗi USB`.
3. Cắm cáp USB, chọn chế độ truyền dữ liệu và chấp nhận hộp thoại RSA trên điện thoại.
4. Kiểm tra thiết bị:

```powershell
D:\Android\platform-tools\adb.exe devices -l
```

5. Ghi lại device ID rồi cài ứng dụng:

```powershell
.\tool\prepare_mobile_test.ps1 -DeviceId DEVICE_ID
```

Điện thoại thật là bắt buộc khi test cân BLE. Emulator có thể test giao diện và API nhưng thường không thể quét ESP32.

## Chọn backend test

Backend ngoài đang là mặc định nên không cần truyền tham số:

```text
https://backend-do-an-api-new.onrender.com
```

Để test một backend khác:

```powershell
.\tool\prepare_mobile_test.ps1 -ApiBaseUrl 'https://api-test.example.com'
```

Nếu backend chạy trên chính máy tính:

- Emulator Android dùng `http://10.0.2.2:PORT`.
- Điện thoại thật dùng IP LAN của máy tính, ví dụ `http://192.168.1.10:PORT`.
- Backend phải lắng nghe trên `0.0.0.0`, điện thoại và máy tính phải chung Wi-Fi, Windows Firewall phải cho phép port đó.

Ví dụ emulator với backend port `5000`:

```powershell
.\tool\prepare_mobile_test.ps1 -ApiBaseUrl 'http://10.0.2.2:5000'
```

## Các loại test tự động

Project có ba tầng test:

| Loại | Vị trí | Mục đích | Lệnh chạy |
| --- | --- | --- | --- |
| Unit test | `test/weight_reading_test.dart` và test model/repository | Kiểm tra parser, tính toán và business logic | `flutter test` |
| Widget test | các file còn lại trong `test/` | Render màn hình, nhập liệu và điều hướng giả lập | `flutter test` |
| Integration test | `integration_test/` | Chạy ứng dụng thật trên emulator/điện thoại | xem lệnh bên dưới |

Chạy toàn bộ unit và widget test:

```powershell
D:\flutter\bin\flutter.bat test
```

Chạy mobile smoke test trên emulator:

```powershell
D:\flutter\bin\flutter.bat test integration_test\mobile_smoke_test.dart -d emulator-5554
```

Chạy integration test đăng nhập với backend thật:

```powershell
D:\flutter\bin\flutter.bat test integration_test\api_login_test.dart `
  -d emulator-5554 `
  --dart-define=TEST_USERNAME=YOUR_USERNAME `
  --dart-define=TEST_PASSWORD=YOUR_PASSWORD
```

Thông tin đăng nhập chỉ được truyền lúc chạy test, không ghi trực tiếp vào source code hoặc commit Git.

Chạy nhanh toàn bộ bằng script:

```powershell
.\tool\run_mobile_tests.ps1
```

Lệnh trên chạy unit test, widget test và mobile smoke test. Nếu muốn chạy thêm đăng nhập API thật:

```powershell
.\tool\run_mobile_tests.ps1 `
  -TestUsername 'YOUR_USERNAME' `
  -TestPassword 'YOUR_PASSWORD'
```

## Checklist smoke test thủ công

| ID | Kiểm tra | Kết quả mong đợi |
| --- | --- | --- |
| MOB-01 | Mở ứng dụng | Hiện màn đăng nhập, không trắng màn hình hoặc crash |
| MOB-02 | Đăng nhập đúng | Vào Home và tên tài khoản lấy từ API |
| MOB-03 | Đăng nhập sai | Hiện thông báo lỗi, không vào Home |
| MOB-04 | Mất mạng | Hiện trạng thái lỗi có thể hiểu được, không crash |
| MOB-05 | Thu mua | Tải lịch, mở chi tiết và nhập kho đúng luồng |
| MOB-06 | Kho | Chỉ hiện sản phẩm còn tồn, mở được chi tiết |
| MOB-07 | Kiểm chất | Hiển thị và lưu đúng nghiệp vụ kiểm chất |
| MOB-08 | Kiểm kê | Nhập được số nhiều chữ số và lưu kết quả |
| MOB-09 | Giao hàng | Tải danh sách, mở chi tiết và hoàn tất đúng dữ liệu |
| MOB-10 | Xay xát | Đi qua chuẩn bị, cân gạo, cân cám và xác nhận |
| MOB-11 | Quyền camera | Cho phép/từ chối quyền đều không làm app crash |
| MOB-12 | Xoay màn hình/Back | Không mất dữ liệu nhập dở hoặc điều hướng sai |

## Checklist cân BLE trên máy thật

1. Bật ESP32 và xác nhận thiết bị quảng bá tên `StockLite SCALE-01`.
2. Vào `Xay xát > Cân gạo > Kết nối cân và nhận số`.
3. Cấp quyền `Thiết bị ở gần` khi Android hỏi.
4. Bấm `Tìm cân`, kiểm tra thiết bị xuất hiện và kết nối được.
5. Đặt bao lên cân; số kg phải thay đổi realtime.
6. Khi payload ổn định, nhãn chuyển thành `ỔN ĐỊNH` và nút nhận số được bật.
7. Nhận liên tiếp nhiều bao; số bao và tổng kg phải tăng đúng.
8. Thử `Cân bì`, `Khởi động lại`, ngắt kết nối và kết nối lại.
9. Tắt Bluetooth giữa chừng; ứng dụng phải báo mất kết nối, không crash.
10. Từ chối quyền Bluetooth; ứng dụng phải hướng dẫn mở Cài đặt.

## Thu thập bằng chứng lỗi

Khi phát hiện lỗi, ghi lại:

- Build/APK và thời gian test.
- Model điện thoại, phiên bản Android.
- Tài khoản/quyền đang dùng, không ghi mật khẩu vào bug report.
- Mạng Wi-Fi/4G và API base URL.
- Bước tái hiện ngắn gọn, kết quả thực tế, kết quả mong đợi.
- Ảnh/video và log ADB.

Lấy log realtime:

```powershell
D:\Android\platform-tools\adb.exe -s DEVICE_ID logcat | Select-String 'flutter|FATAL EXCEPTION|SocketException'
```

Lưu toàn bộ log vào file:

```powershell
D:\Android\platform-tools\adb.exe -s DEVICE_ID logcat -d > mobile-test-log.txt
```
