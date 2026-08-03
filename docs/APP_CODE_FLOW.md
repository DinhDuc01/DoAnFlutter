# Luồng code của ứng dụng

## 1. Luồng khởi động

```text
main()
  -> StockLiteApp
  -> ValueListenableBuilder<ThemeMode>
  -> MaterialApp
  -> AppRoutes.login
  -> LoginScreen
```

1. `lib/main.dart` gọi `runApp(const StockLiteApp())`.
2. `lib/app/app.dart` đọc theme hiện tại từ `ThemeController`.
3. `MaterialApp` đăng ký `AppRoutes.routes`.
4. Route khởi đầu là `/login`.

## 2. Luồng đăng nhập

```text
LoginScreen
  -> ApiAuthService.login()
  -> ApiClient.post('/api/v1/auth/login')
  -> JsonReader đọc resources
  -> AuthSession
  -> AuthSessionStore.current
  -> Navigator chuyển tới /home
```

Sau khi đăng nhập, `AuthSessionStore.current` giữ tạm thời:

- `accessToken`: gắn vào header `Authorization` của request cần đăng nhập.
- `refreshToken`: backend trả về nhưng app chưa tự refresh token.
- `AuthUser`: ID, tên, email và avatar của tài khoản.

Session hiện chỉ nằm trong bộ nhớ. Khi đóng hẳn app, người dùng phải đăng nhập lại.

## 3. Luồng Home

`HomeScreen` dùng `IndexedStack` để giữ trạng thái của sáu tab:

| Index | Widget | Chức năng |
| --- | --- | --- |
| 0 | `HomeTodayTab` | Tổng quan và phím tắt. Một số nội dung tổng quan vẫn là dữ liệu giao diện local. |
| 1 | `ThuMuaTab` | Lịch thu mua lấy từ API. |
| 2 | `KhoTab` | Danh sách sản phẩm và tồn kho lấy từ API. |
| 3 | `GiaoHangTab` | Sản phẩm có thể xuất và kho chứa lấy từ API. |
| 4 | `NotificationsTab` | Thông báo của tài khoản lấy từ API. |
| 5 | `AccountTab` | Tên và email lấy từ session đăng nhập. |

Các phím tắt trong `HomeTodayTab` chuyển tab hoặc mở route nghiệp vụ riêng.

## 4. Route hiện tại

| Route | Màn hình |
| --- | --- |
| `/login` | `LoginScreen` |
| `/home` | `HomeScreen` |
| `/thu-mua` | `ThuMuaScreen` |
| `/thu-mua/detail` | `PurchaseScheduleDetailScreen` |
| `/thu-mua/success` | `ThuMuaSuccessScreen` |
| `/giao-hang` | `GiaoHangScreen` |
| `/giao-hang/success` | `GiaoHangSuccessScreen` |
| `/kho` | `KhoScreen` |
| `/products/detail` | `ProductDetailScreen` |
| `/scan-qr` | `ScanQrScreen` |
| `/reports` | `ReportsScreen` |
| `/history` | `OperationHistoryScreen` |
| `/notifications` | `NotificationsScreen` |
| `/account` | `AccountScreen` |
| `/change-password` | `ChangePasswordScreen` |
| `/xay-xat` | `MillingPreparationScreen` |

## 5. Luồng Thu mua và nhập kho

```text
ThuMuaTab
  -> PurchaseScheduleRepository.getSchedules()
  -> hiển thị lịch thu mua thật
  -> bấm một lịch
  -> PurchaseScheduleDetailScreen
  -> GET /api/v1/farmers/{farmerId}
  -> hiển thị nông dân, điện thoại, địa điểm, giống, giá và trạng thái
  -> Bắt đầu cân tại nhà
  -> nút tạo phiếu
  -> ThuMuaScreen
  -> ApiThuMuaRepository.getDraftReceipt()
  -> chọn sản phẩm ít tồn + kho mặc định
  -> xác nhận
  -> manual-adjustment số dương
  -> ThuMuaSuccessScreen
```

## 6. Luồng Kho, kiểm chất và kiểm kê

```text
KhoTab / KhoScreen
  -> ApiKhoCheckRepository
  -> ProductVariantApi.activeVariantsWithStock()
  -> product-variant/search
  -> inventories/by-variant/{id}
  -> KhoCheck model
  -> hiển thị tồn hệ thống
```

`KhoTab` chỉ hiển thị tồn kho và chi tiết sản phẩm.

`Kiểm chất` mở route `/quality-inspections`, đọc các phiếu
`QualityInspection` của lô lúa/gạo. Các chỉ số gồm độ ẩm, tạp chất, nấm mốc,
sâu mọt, bao bì và kết quả đạt/không đạt.

`Kiểm kê` mở route `/stocktake`. Mobile chọn đúng một kho từ dữ liệu tồn,
người dùng nhập số lượng đếm thực tế và app gửi `POST /api/v1/stocktake`.
Backend tự tạo phiếu trạng thái `Draft`; nghiệp vụ này không sử dụng các chỉ số
chất lượng.

## 7. Luồng Giao hàng

```text
GiaoHangTab
  -> ApiGiaoHangRepository.getDraftReceipt()
  -> tìm sản phẩm và kho còn tồn khả dụng
  -> GiaoHangScreen
  -> kiểm tra số lượng <= tồn khả dụng
  -> manual-adjustment số âm
  -> GiaoHangSuccessScreen
```

`GiaoHangTab` tải tất cả sản phẩm còn tồn khả dụng theo từng kho/vị trí. Khi
chọn một dòng, `GiaoHangScreen` tải danh sách khách hàng từ
`GET /api/v1/customers`, cho chọn người nhận và số lượng. Xác nhận giao hàng
dùng inventory manual adjustment số âm tại đúng `warehouseId` và `locationId`.

Sau khi thành công, `GiaoHangDetailScreen` hiển thị sản phẩm, khách hàng, kho,
vị trí, số lượng giao và tồn còn lại. Backend hiện chưa expose controller
SalesOrder/OutboundOrder nên mobile chưa thể lưu một chứng từ giao hàng độc lập;
thông tin khách hàng được ghi vào lý do của inventory transaction.

## 8. Luồng Xay xát

```text
HomeTodayTab
  -> /xay-xat
  -> ApiMillingRepository.getActiveOrder()
  -> MillingPreparationScreen
  -> RiceWeighingScreen
     -> ScaleScreen -> BleScaleService -> ESP32 BLE
  -> BranWeighingScreen
     -> ScaleScreen -> BleScaleService -> ESP32 BLE
  -> MillingResultConfirmationScreen
  -> ApiMillingRepository.completeOrder()
```

Lệnh xay được tải từ API. Mỗi bao gạo/cám được nhận từ cân BLE khi payload báo `s: true`, sau đó được giữ trong model mobile; backend chưa có endpoint riêng để lưu từng lần cân trước khi hoàn tất.

## 9. Luồng tài khoản

```text
AccountTab
  -> AuthSessionStore.current.user

AccountScreen
  -> ApiAccountRepository
  -> GET /api/v1/auth/me
  -> GET /api/v1/warehouse
  -> AccountProfile
```

Màn đổi mật khẩu hiện mới xử lý giao diện local, chưa gọi `PUT /api/v1/user/me/change-password`.

Chi tiết cách repository tạo request, gắn token và parse response nằm tại [API_INTEGRATION_FLOW.md](API_INTEGRATION_FLOW.md).
