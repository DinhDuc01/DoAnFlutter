# Luồng Xay xát trên Tuấn Mây Mobile

## 1. Phạm vi nghiệp vụ

Mobile dùng cho nhân viên tại xưởng ghi nhận kết quả đóng bao sau xay. Web admin tiếp tục phụ trách lập lệnh, phân lô, duyệt và theo dõi quản trị.

Tên gọi thống nhất:

| Khái niệm | Tên trong Flutter | Tên backend |
| --- | --- | --- |
| Lệnh xay | `MillingOrder` | `MillingOrder` |
| Bao thành phẩm | `MillingBag` trong `riceBags` | Output `RICE` |
| Bao cám | `MillingBag` trong `branBags` | Output `BRAN` |
| Hoàn tất mẻ | `completeOrder()` | `POST /api/v1/milling-orders/{id}/complete` |

Không dùng tên `KhoScreen`, `InventoryScreen` hoặc `Cân IoT` cho feature này vì đây là một phần của nghiệp vụ Xay xát, không phải một khu vực kho độc lập.

## 2. Cấu trúc code

```text
lib/features/milling/
  data/
    api_milling_repository.dart
    milling_repository.dart
  models/
    milling_order.dart
  presentation/
    screens/
      milling_preparation_screen.dart
      rice_weighing_screen.dart
      bran_weighing_screen.dart
      milling_result_confirmation_screen.dart
    widgets/
      milling_widgets.dart

lib/features/scale/
  data/
    ble_scale_service.dart
  models/
    weight_reading.dart
  presentation/screens/
    scale_screen.dart
```

`MillingRepository` là ranh giới dữ liệu API. `BleScaleService` quản lý Bluetooth, tìm ESP32, đăng ký notify và đọc trọng lượng; UI không tự gọi HTTP hoặc BLE trực tiếp.

## 3. Luồng màn hình

```text
Home - Xay xát
  -> Hoàn tất xay & đóng bao
  -> Cân gạo sau xay
  -> Cân cám sau xay
  -> Xác nhận kết quả xay
  -> Hoàn tất mẻ xay
  -> Về trang chủ
```

### Chuẩn bị

- Hiển thị mã lệnh, lô lúa, khối lượng đầu vào, khu vực, ô kệ và mã cân.
- Màn hình tự hiển thị loading theo `Future`, error theo exception và dữ liệu khi API trả thành công; người dùng không chọn trạng thái thủ công.
- Nút `Bắt đầu cân gạo` mở bước cân thành phẩm.

### Cân gạo

- Mở `ScaleScreen`, tìm thiết bị `StockLite`, kết nối và nhận payload BLE.
- Chỉ cho thêm bao khi cân trả về số lớn hơn 0 và trạng thái ổn định `s: true`.
- Hiển thị số bao đã cân, tổng kg và khối lượng từng bao.
- Lưu danh sách `riceBags` trước khi chuyển sang cân cám.

### Cân cám

- Dùng màu cam để phân biệt phụ phẩm với gạo thành phẩm.
- Mỗi lần nhận số cân ổn định sẽ thêm một `MillingBag` mới, vì vậy có thể cân nhiều bao liên tiếp.
- Hiển thị số bao, tổng cám và từng lần cân.
- Lưu `branBags` trước khi xác nhận.

### Xác nhận

- Tổng gạo = tổng khối lượng `riceBags`.
- Tổng cám = tổng khối lượng `branBags`.
- Yield gạo = `tổng gạo / lúa đầu vào * 100`.
- Nhân viên kiểm tra chi tiết từng bao trước khi hoàn tất.

## 4. Trạng thái API

Phiên bản chạy thật dùng `ApiMillingRepository`. `MockMillingRepository` chỉ còn phục vụ widget test và kiểm tra luồng offline.

Backend hiện có:

```text
GET  /api/v1/milling-orders
GET  /api/v1/milling-orders/{id}
POST /api/v1/milling-orders
PUT  /api/v1/milling-orders
POST /api/v1/milling-orders/{id}/complete
```

Mobile đã tải danh sách/detail và gọi endpoint `complete`. Backend vẫn cần endpoint rõ ràng để lưu từng lần cân trước khi hoàn tất, gồm tối thiểu `OutputType`, `OutputWeightKg`, `BagCount`, `IsByproduct` và vị trí nhập kho đầu ra.

Backend hiện chỉ trả tổng đầu ra, không trả từng lần cân. Mobile không chia tổng này thành các bao giả; danh sách bao của phiên làm việc chỉ được tạo từ số cân BLE.

## 5. Quy tắc kiểm tra

- Không cho hoàn tất khi chưa có bao gạo hoặc bao cám.
- Khối lượng từng bao phải lớn hơn 0.
- Tổng đầu ra và hao hụt không được vượt tổng lúa đầu vào ngoài dung sai backend.
- Chỉ hoàn tất một lần; lệnh Completed không được ghi cân lại.
- Khi mất mạng trong lúc lưu, giữ dữ liệu cân local để người dùng thử lại.
