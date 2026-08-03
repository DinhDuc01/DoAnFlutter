# Luồng kết nối API của ứng dụng

## 1. Base URL

Base URL được đọc tại `lib/core/config/api_config.dart`:

```dart
static const baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://backend-do-an-api-new.onrender.com',
);
```

Nếu không truyền `--dart-define`, app kết nối server Render bên ngoài.

### Android emulator gọi backend trên máy tính

```powershell
flutter run -d emulator-5554 `
  --dart-define=API_BASE_URL=https://10.0.2.2:<PORT>
```

`10.0.2.2` là địa chỉ đặc biệt để Android emulator truy cập máy host. Không dùng `localhost` trong emulator vì `localhost` khi đó là chính máy ảo.

### Điện thoại thật gọi backend trên máy tính

```powershell
flutter run -d <device-id> `
  --dart-define=API_BASE_URL=http://<IP-LAN-CUA-MAY>:<PORT>
```

Điện thoại và máy tính phải cùng mạng; backend phải listen trên interface mạng và firewall phải cho phép port đó.

## 2. Chuỗi xử lý một request

```text
Screen/Tab
  -> Repository interface
  -> Api...Repository hoặc API service
  -> AuthSessionStore lấy accessToken
  -> ApiClient ghép baseUrl + path
  -> Authorization: Bearer <token>
  -> Backend
  -> JSON response
  -> JsonReader
  -> Model
  -> FutureBuilder/setState cập nhật UI
```

`ApiClient` hiện hỗ trợ `GET` và `POST`. Các API cần `PUT`, `PATCH` hoặc `DELETE` phải bổ sung phương thức tương ứng vào client trước khi nối vào UI.

## 3. Xử lý response

Backend thường trả dạng:

```json
{
  "isSucceeded": true,
  "message": "...",
  "resources": {}
}
```

`JsonReader` đọc key không phân biệt chữ hoa/thường và hỗ trợ chuyển `int`, `double`, `String`, `bool`, `List` và `Map`.

Nếu HTTP status không thuộc 2xx, `ApiClient` ném `ApiException`. Repository có thể đổi lỗi này thành exception theo nghiệp vụ trước khi UI hiển thị.

## 4. API theo chức năng

| Chức năng | Repository/service | Endpoint chính | Trạng thái |
| --- | --- | --- | --- |
| Đăng nhập | `ApiAuthService` | `POST /api/v1/auth/login` | Đã nối |
| Lịch thu mua | `PurchaseScheduleRepository` | `GET /api/v1/paddy-purchase-schedules` | Đã nối |
| Chi tiết lịch thu mua | `PurchaseScheduleRepository` | `GET /api/v1/farmers/{farmerId}` bổ sung liên hệ nông dân | Đã nối |
| Phiếu nhập | `ApiThuMuaRepository` | Product, inventory, warehouse; `POST .../manual-adjustment` | Đã nối |
| Kho | `ProductVariantApi` | `GET /api/v1/product-variant/search`, `GET /api/v1/inventories/by-variant/{id}` | Đã nối đọc |
| Kiểm chất | `ApiQualityInspectionRepository` | `GET /api/v1/quality-inspections` | Đã nối đọc, tách khỏi kiểm kê |
| Kiểm kê | `ApiKhoCheckRepository` | Tồn của đúng một kho; `POST /api/v1/stocktake` | Đã nối tạo phiếu nháp |
| Giao hàng | `ApiGiaoHangRepository` | Product/inventory, `GET /api/v1/customers`; `POST .../manual-adjustment` với số âm | Đã nối theo API backend hiện có |
| Thông báo | `ApiNotificationsRepository` | `POST /api/v1/notification/me` | Đã nối REST, chưa realtime |
| Hồ sơ | `ApiAccountRepository` | `GET /api/v1/auth/me`, `GET /api/v1/warehouse` | Đã nối |
| Đổi mật khẩu | Chưa có repository | `PUT /api/v1/user/me/change-password` | UI local |
| Xay xát | `ApiMillingRepository` | `GET /api/v1/milling-orders`, detail, complete | Đã nối một phần |
| Lịch sử | `MockOperationHistoryRepository` | Inventory transaction advanced | Backend đang trả 500 |
| Báo cáo | `MockWarehouseReportRepository` | `GET /api/v1/dashboard/report-statistics` | Backend chưa implement |
| Quét QR | `mobile_scanner` | Chưa có endpoint validate thống nhất | Local |

## 5. Chi tiết lịch thu mua

Khi mở chi tiết một lịch, app truyền `PurchaseSchedule` từ danh sách sang route `/thu-mua/detail`, sau đó tải thêm thông tin nông dân. Loading, error và data được quyết định tự động từ `FutureBuilder`; màn hình không có bộ chọn state thủ công.

Nút `Bắt đầu cân tại nhà` mở phiếu nhập kho hiện có. Lịch đã hủy sẽ khóa nút này.

## 6. Chi tiết nhập kho

Request xác nhận nhập kho:

```json
{
  "productVariantId": 1,
  "warehouseId": 1,
  "locationId": null,
  "adjustmentQuantity": 10,
  "reason": "Nhập kho mobile PN-2026-API"
}
```

`adjustmentQuantity` là số dương nên tồn kho tăng.

## 7. Chi tiết xuất kho

Request xác nhận xuất kho dùng cùng endpoint:

```json
{
  "productVariantId": 1,
  "warehouseId": 1,
  "locationId": null,
  "adjustmentQuantity": -5,
  "reason": "Giao hàng GH-... - Khách: <tên khách>"
}
```

Trước khi gửi, mobile kiểm tra số lượng lớn hơn 0 và không vượt tồn khả dụng.

## 8. Token và phiên đăng nhập

- Token được lấy từ response login và giữ tại `AuthSessionStore.current`.
- Repository cần đăng nhập phải kiểm tra token trước khi gửi request.
- Token chỉ lưu trong RAM, chưa dùng secure storage.
- App chưa tự gọi refresh token khi access token hết hạn.
- Đăng xuất hiện chủ yếu xóa luồng điều hướng; cần bổ sung xóa session và gọi API logout trong bước hoàn thiện bảo mật.

## 9. SSL và nền tảng

`ApiClient` dùng `dart:io HttpClient` và chỉ bỏ qua certificate lỗi cho:

- `10.0.2.2`
- `localhost`
- `127.0.0.1`
- host development cũ `15.135.109.251`

`badCertificateCallback` không quyết định app gọi server nào. Server được chọn hoàn toàn bởi `ApiConfig.baseUrl`.

Client hiện phù hợp Android/Windows. Vì dùng `dart:io`, cần một HTTP adapter hỗ trợ browser trước khi coi bản Flutter Web là đã nối API đầy đủ.

## 10. Nguyên tắc khi nối endpoint mới

1. Xác nhận method, path, body và response từ backend thật.
2. Thêm model mobile nếu dữ liệu chưa có model phù hợp.
3. Khai báo phương thức trong repository interface.
4. Hiện thực request trong `Api...Repository`.
5. Parse bằng `JsonReader`, không parse rải rác trong widget.
6. Hiển thị loading, empty, error và retry trong UI.
7. Viết test bằng fake/mock repository; không gọi server production trong widget test.
8. Chạy `flutter analyze`, `flutter test` và kiểm tra trên thiết bị thật hoặc emulator.
