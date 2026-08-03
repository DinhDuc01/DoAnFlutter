# StockLite Full Project Test Scope

Tài liệu này được lập sau khi rà soát source code hiện tại của project StockLite.

Mục tiêu: giúp tester biết **cần test tất cả những gì**, theo đúng các màn hình, route, mock data, tương tác UI và các điểm sau này sẽ thay bằng API.

## 1. Tổng quan project

Project hiện là app Flutter mobile quản lý thao tác kho.

Entry point:

```text
lib/main.dart
lib/app/app.dart
```

App name:

```text
StockLite
```

Package:

```text
pubspec.yaml: stocklite
Android applicationId: com.stocklite.app
```

Kiến trúc chính:

```text
lib/
  app/
  core/
  features/
```

Các feature hiện có:

```text
auth
home
inbound
outbound
inventory
history
notifications
account
scan
reports
products
```

## 2. Routes cần test

File route:

```text
lib/core/routes/app_routes.dart
```

Danh sách route:

| Route | Màn hình | Trạng thái |
| --- | --- | --- |
| `/login` | Đăng nhập | Có UI |
| `/home` | Trang chủ | Có UI |
| `/inbound` | Phiếu nhập kho | Có UI |
| `/inbound/success` | Nhập kho thành công | Có UI |
| `/outbound` | Phiếu xuất kho | Có UI |
| `/outbound/success` | Xuất kho thành công | Có UI |
| `/inventory` | Phiếu kiểm kho | Có UI |
| `/scan-qr` | Quét mã QR | UI mock, chưa có camera thật |
| `/reports` | Báo cáo | Placeholder |
| `/history` | Lịch sử thao tác | Có UI |
| `/notifications` | Thông báo | Có UI |
| `/account` | Tài khoản | Có UI |
 | `/products/detail` | Thông tin sản phẩm | Placeholder |
 | `/xay-xat` | Hoàn tất xay và đóng bao | Có UI đầy đủ, repository mock |

## 3. Test kỹ thuật bắt buộc

Chạy trước mỗi vòng test:

```powershell
flutter pub get
flutter analyze
flutter test
```

Kết quả mong đợi:

```text
No issues found
All tests passed
```

Build/run cơ bản:

```powershell
flutter run
```

Nếu cần kiểm Android package:

```powershell
flutter build apk --debug
```

## 4. Smoke test toàn app

| ID | Case | Expected |
| --- | --- | --- |
| SM-01 | Mở app | Vào màn Login |
| SM-02 | Login mock | Bấm Đăng nhập vào Home |
| SM-03 | Home quick actions | 6 action hiển thị |
| SM-04 | Mở Nhập kho | Không crash, đúng màn Phiếu nhập |
| SM-05 | Mở Xuất kho | Không crash, đúng màn Phiếu xuất |
| SM-06 | Mở Kiểm kho | Không crash, đúng màn Phiếu kiểm |
| SM-07 | Mở Quét QR | Không crash, đúng màn Quét mã QR |
| SM-08 | Mở Lịch sử | Không crash, đúng màn Lịch sử thao tác |
| SM-09 | Bottom nav Thông báo | Vào màn Thông báo |
| SM-10 | Bottom nav Tài khoản | Vào màn Tài khoản |
| SM-11 | Back/navigation | Không bị kẹt route, không màn trắng |

## 5. Auth / Login

Source:

```text
lib/features/auth/
```

Files chính:

```text
data/auth_service.dart
data/mock_auth_service.dart
presentation/screens/login_screen.dart
```

Hiện trạng:

- Dùng mock auth.
- Email mặc định: `nhanvien@stocklite.vn`.
- Password mặc định: `123456`.
- Login thành công nếu email/password không rỗng.

Test cases:

| ID | Case | Steps | Expected |
| --- | --- | --- | --- |
| AUTH-01 | Brand | Mở app | Thấy `StockLite` |
| AUTH-02 | Subtitle | Mở app | Thấy mô tả app |
| AUTH-03 | Email default | Mở app | Email mặc định đúng |
| AUTH-04 | Password masked | Mở app | Password bị ẩn |
| AUTH-05 | Login success | Bấm Đăng nhập | Điều hướng sang Home |
| AUTH-06 | Loading state | Bấm Đăng nhập | Nút chuyển trạng thái loading ngắn |
| AUTH-07 | Empty email | Xóa email, bấm login | Không nên vào app sau khi có validation thật |
| AUTH-08 | Empty password | Xóa password, bấm login | Không nên vào app sau khi có validation thật |

Regression sau API:

- Sai tài khoản phải báo lỗi.
- Token phải được lưu.
- Logout phải xóa token.
- App mở lại phải kiểm tra session.

## 6. Home / Trang chủ

Source:

```text
lib/features/home/
```

Files chính:

```text
models/quick_action.dart
models/recent_activity.dart
presentation/screens/home_screen.dart
presentation/widgets/home_header.dart
presentation/widgets/quick_action_grid.dart
presentation/widgets/recent_activity_card.dart
presentation/widgets/home_bottom_nav.dart
```

Test cases:

| ID | Case | Expected |
| --- | --- | --- |
| HOME-01 | Header user | Hiển thị lời chào, tên user, avatar |
| HOME-02 | Kho hoạt động | Hiển thị kho đang hoạt động |
| HOME-03 | Quick action count | Có 6 action |
| HOME-04 | Action Nhập kho | Điều hướng `/inbound` |
| HOME-05 | Action Xuất kho | Điều hướng `/outbound` |
| HOME-06 | Action Kiểm kho | Điều hướng `/inventory` |
| HOME-06A | Action Xay xát | Điều hướng `/xay-xat`, không mở nhầm tab Kho |
| HOME-07 | Action Quét QR | Điều hướng `/scan-qr` |
| HOME-08 | Action Thống kê | Điều hướng `/reports` placeholder |
| HOME-09 | Action Lịch sử | Điều hướng `/history` |
| HOME-10 | Recent activities | Hiển thị danh sách hoạt động gần đây |
| HOME-11 | Bottom nav Thông báo | Điều hướng `/notifications` |
| HOME-12 | Bottom nav Tài khoản | Điều hướng `/account` |

UI cần kiểm:

- Grid không vỡ trên màn nhỏ.
- Text action không tràn.
- Recent activity card không overflow.
- Bottom nav không che nội dung.

 ## 7. Inbound / Nhập kho

Source:

```text
lib/features/inbound/
```

Files chính:

```text
data/inbound_repository.dart
models/inbound_receipt.dart
presentation/screens/inbound_screen.dart
presentation/screens/inbound_success_screen.dart
presentation/widgets/*
```

Mock data:

- Product: Bóng đèn LED 9W
- Receipt: PN-2025-005
- Quantity: 50
- Weight: 0.15

Test cases:

| ID | Case | Expected |
| --- | --- | --- |
| IN-01 | Load draft | Hiển thị phiếu nhập |
| IN-02 | Product card | Tên sản phẩm, SKU, tồn kho đúng |
| IN-03 | Receipt fields | Mã phiếu, khối lượng đúng |
| IN-04 | Quantity initial | Số lượng ban đầu đúng mock |
| IN-05 | Increase quantity | Bấm `+`, số tăng |
| IN-06 | Decrease quantity | Bấm `-`, số giảm |
| IN-07 | Quantity not negative | Giảm nhiều lần, không âm |
| IN-08 | Note input | Nhập ghi chú được |
| IN-09 | Confirm | Chuyển sang `/inbound/success` |
| IN-10 | Success quantity | Màn success hiển thị số lượng đúng |
| IN-11 | Success receipt code | Mã phiếu đúng |
| IN-12 | Success back home | Bấm Quay về trang chủ về Home |

API_SWAP cần test sau này:

- `GET /inbound/draft`
- `POST /inbound/confirm`
- Response success truyền đúng sang màn success.
- Error API hiển thị trạng thái lỗi.

## 8. Outbound / Xuất kho

Source:

```text
lib/features/outbound/
```

Files chính:

```text
data/outbound_repository.dart
models/outbound_receipt.dart
presentation/screens/outbound_screen.dart
presentation/screens/outbound_success_screen.dart
presentation/widgets/*
```

Mock data:

- Product: Cáp sạc Type-C 1m
- Receipt: PX-2025-005
- Customer: Siêu thị BigC
- Quantity: 20

Test cases:

| ID | Case | Expected |
| --- | --- | --- |
| OUT-01 | Load draft | Hiển thị phiếu xuất |
| OUT-02 | Product card | Tên sản phẩm, SKU, tồn kho đúng |
| OUT-03 | Receipt fields | Mã phiếu, khách hàng đúng |
| OUT-04 | Quantity initial | Số lượng ban đầu đúng mock |
| OUT-05 | Increase quantity | Bấm `+`, số tăng |
| OUT-06 | Decrease quantity | Bấm `-`, số giảm |
| OUT-07 | Quantity not negative | Giảm nhiều lần, không âm |
| OUT-08 | Note input | Nhập ghi chú được |
| OUT-09 | Confirm | Chuyển sang `/outbound/success` |
| OUT-10 | Success quantity | Màn success hiển thị số lượng đúng |
| OUT-11 | Success receipt code | Mã phiếu đúng |
| OUT-12 | Success back home | Bấm Quay về trang chủ về Home |

API_SWAP cần test sau này:

- `GET /outbound/draft`
- `POST /outbound/confirm`
- Không cho xuất quá tồn kho.
- Error API hiển thị hợp lý.

## 9. Inventory / Kiểm kho

Source:

```text
lib/features/inventory/
```

Files chính:

```text
data/inventory_check_repository.dart
models/inventory_check.dart
presentation/screens/inventory_screen.dart
presentation/widgets/*
```

Mock data:

- Check code: KK-2025-003
- Warehouse: Kho A
- Items:
  - Bóng đèn LED 9W, system 20, actual 1
  - Cáp sạc Type-C 1m, system 245
  - Áo thun nam size L, system 30

Test cases:

| ID | Case | Expected |
| --- | --- | --- |
| INV-01 | Load draft | Hiển thị phiếu kiểm |
| INV-02 | Summary fields | Mã phiếu và kho đúng |
| INV-03 | Hint banner | Có hướng dẫn nhập số thực tế |
| INV-04 | Item list | Hiển thị đủ item |
| INV-05 | Actual input | Nhập số vào ô Thực tế |
| INV-06 | Difference negative | Actual < system hiển thị số âm |
| INV-07 | Difference positive | Actual > system hiển thị số dương |
| INV-08 | Difference empty | Actual trống hiển thị `—` |
| INV-09 | Digits only | Không nhập được ký tự chữ |
| INV-10 | Note input | Nhập ghi chú được |
| INV-11 | Confirm | Bấm xác nhận hiển thị mock confirmation |

API_SWAP cần test sau này:

- `GET /inventory-check/draft`
- `POST /inventory-check/confirm`
- Payload gồm checkCode, note, sku, actualQuantity.
- Backend trả lỗi item invalid phải hiển thị được.

## 10. History / Lịch sử thao tác

Source:

```text
lib/features/history/
```

Files chính:

```text
data/operation_history_repository.dart
models/operation_history.dart
presentation/screens/operation_history_screen.dart
presentation/widgets/*
```

Test cases:

| ID | Case | Expected |
| --- | --- | --- |
| HIS-01 | Load list | Hiển thị danh sách lịch sử |
| HIS-02 | Count | Header hiển thị số giao dịch |
| HIS-03 | Inbound item | Màu xanh, quantity có `+` |
| HIS-04 | Outbound item | Màu đỏ, quantity âm |
| HIS-05 | Inventory item | Màu tím, quantity âm/diff |
| HIS-06 | Date format | Hiển thị ngày giờ ngắn |
| HIS-07 | Empty state | Khi list rỗng hiển thị empty |
| HIS-08 | Error state | Khi API lỗi hiển thị lỗi |

API_SWAP:

- `GET /operation-histories`
- Filter/sort/pagination nếu backend có.

## 11. Notifications / Thông báo

Source:

```text
lib/features/notifications/
```

Files chính:

```text
data/notifications_repository.dart
models/app_notification.dart
presentation/screens/notifications_screen.dart
presentation/widgets/*
```

Test cases:

| ID | Case | Expected |
| --- | --- | --- |
| NOTI-01 | Load list | Hiển thị danh sách thông báo |
| NOTI-02 | Unread count | Header hiển thị số chưa đọc |
| NOTI-03 | Filter all | Hiển thị tất cả |
| NOTI-04 | Filter unread | Chỉ hiển thị chưa đọc |
| NOTI-05 | Filter alerts | Chỉ hiển thị cảnh báo |
| NOTI-06 | Badge unread | Chip Chưa đọc có badge |
| NOTI-07 | Mark all read | Bấm Đọc tất cả, unread về 0 |
| NOTI-08 | Dismiss | Bấm `x`, item biến mất |
| NOTI-09 | Empty filter | Không có item phù hợp thì hiện empty |
| NOTI-10 | Bottom nav active | Tab Thông báo active |

API_SWAP:

- `GET /notifications`
- `PATCH /notifications/read-all`
- `DELETE /notifications/{id}` hoặc dismiss endpoint.

## 12. Account / Tài khoản

Source:

```text
lib/features/account/
```

Files chính:

```text
data/account_repository.dart
models/account_profile.dart
presentation/screens/account_screen.dart
presentation/widgets/*
```

Test cases:

| ID | Case | Expected |
| --- | --- | --- |
| ACC-01 | Load profile | Hiển thị tên, email, role |
| ACC-02 | Avatar | Hiển thị chữ cái avatar |
| ACC-03 | Stats | Nhập/Xuất/Kiểm hiển thị đúng |
| ACC-04 | Warehouse card | Hiển thị kho phụ trách |
| ACC-05 | Toggle notifications | Switch đổi trạng thái |
| ACC-06 | Toggle dark mode | Switch đổi trạng thái |
| ACC-07 | Language row | Hiển thị ngôn ngữ |
| ACC-08 | Change password row | Bấm không crash |
| ACC-09 | Help row | Bấm không crash |
| ACC-10 | Logout | Quay về Login, clear navigation stack |
| ACC-11 | Bottom nav active | Tab Tài khoản active |

API_SWAP:

- `GET /me` hoặc `GET /account/profile`
- `PATCH /account/settings`
- `POST /auth/logout`
- Clear token storage.

## 13. Scan QR

Source:

```text
lib/features/scan/
```

Files chính:

```text
presentation/screens/scan_qr_screen.dart
presentation/widgets/scan_header.dart
presentation/widgets/scan_camera_preview.dart
presentation/widgets/scan_action_panel.dart
presentation/widgets/scan_bottom_bar.dart
```

Hiện trạng:

- UI mock.
- Chưa dùng camera thật.
- Nút Quét ngay hiện SnackBar mock.

Test cases:

| ID | Case | Expected |
| --- | --- | --- |
| QR-01 | Load screen | Header `Quét mã QR` |
| QR-02 | Back | Quay lại màn trước |
| QR-03 | Flash button | Bấm không crash |
| QR-04 | Scan frame | Khung scan hiển thị |
| QR-05 | Scan now | Hiện SnackBar mock |
| QR-06 | Switch camera | Bấm không crash |
| QR-07 | Photo library | Bấm không crash |
| QR-08 | Bottom nav | Điều hướng Home/Thông báo/Tài khoản |

Sau này khi thêm camera thật:

- Permission camera granted/denied.
- Scan QR valid.
- Scan QR invalid.
- Duplicate scan debounce.
- Open image library.
- Switch front/back camera.
- Flash on/off.

## 14. Reports / Báo cáo

Source:

```text
lib/features/reports/presentation/screens/reports_screen.dart
```

Hiện trạng:

- Placeholder.

Test cases hiện tại:

| ID | Case | Expected |
| --- | --- | --- |
| REP-01 | Open reports | Mở từ Home không crash |
| REP-02 | Placeholder content | Hiển thị title/description placeholder |
| REP-03 | Back | Quay lại được |

Sau này khi làm thật cần test:

- Chart/load data.
- Date range.
- Filter kho/sản phẩm.
- Empty state.
- Export nếu có.

## 15. Product detail / Thông tin sản phẩm

Source:

```text
lib/features/products/presentation/screens/product_detail_screen.dart
```

Hiện trạng:

- Placeholder.
- Chưa có entry chính từ Home.

Test cases hiện tại:

| ID | Case | Expected |
| --- | --- | --- |
| PROD-01 | Route exists | Route `/products/detail` mở được nếu gọi trực tiếp |
| PROD-02 | Placeholder content | Hiển thị title/description placeholder |

Sau này khi làm thật cần test:

- Product info.
- SKU/barcode.
- Stock by warehouse.
- Recent transactions.
- Image/asset.
- Error/empty state.

## 16. Bottom navigation cần test chéo

Các màn có bottom nav:

- Home
- Inbound
- Inbound success
- Outbound
- Outbound success
- Inventory
- History
- Notifications
- Account
- Scan QR

Test chung:

| ID | Case | Expected |
| --- | --- | --- |
| NAV-01 | Tap Home | Về Home |
| NAV-02 | Tap Notifications | Vào Notifications |
| NAV-03 | Tap Account | Vào Account |
| NAV-04 | Active tab | Tab hiện tại màu xanh |
| NAV-05 | Stack handling | Home dùng `pushNamedAndRemoveUntil` không stack lặp quá nhiều |
| NAV-06 | Back behavior | Back không bị loop kỳ lạ |

## 17. UI/Responsive cần test

Test trên ít nhất:

- Small Phone emulator.
- Một màn hình Android lớn hơn.

Checklist:

- Text tiếng Việt hiển thị đúng dấu.
- Không có text lỗi encoding.
- Text không bị overflow.
- Card không bị vỡ layout.
- Danh sách scroll được.
- Bottom nav không che nút chính.
- Success screen căn giữa ổn.
- QR dark screen không bị thiếu nút ở màn thấp.
- Keyboard không che input ghi chú nghiêm trọng.

## 18. State cần test

Các state hiện có hoặc cần giả lập khi nối API:

| State | Màn |
| --- | --- |
| Loading | Inbound, Outbound, Inventory, History, Notifications, Account |
| Success data | Tất cả màn dùng repository |
| Empty list | History, Notifications |
| Error | Inbound, Outbound, Inventory, History, Notifications, Account |
| Local update | Quantity stepper, inventory actual input, notification dismiss, settings toggle |
| Navigation result | Inbound success, Outbound success |

## 19. Automated test nên có

Hiện có:

```text
test/widget_test.dart
```

Nên bổ sung:

```text
integration_test/login_flow_test.dart
integration_test/warehouse_flow_test.dart
integration_test/navigation_flow_test.dart
```

Automated test đề xuất:

| ID | Test | Type |
| --- | --- | --- |
| AUTO-01 | App shows Login | Widget |
| AUTO-02 | Login opens Home | Integration |
| AUTO-03 | Home opens Inbound | Integration |
| AUTO-04 | Inbound confirm opens success | Integration |
| AUTO-05 | Home opens Outbound | Integration |
| AUTO-06 | Outbound confirm opens success | Integration |
| AUTO-07 | Home opens Inventory | Integration |
| AUTO-08 | Home opens Notifications | Integration |
| AUTO-09 | Home opens Account | Integration |
| AUTO-10 | Home opens QR | Integration |
| AUTO-11 | Notification filters work | Widget/Integration |
| AUTO-12 | Inventory difference calculation | Widget/Unit |

## 20. Known issues / cần chú ý khi test

Khi rà source, cần đặc biệt kiểm tra:

- Text tiếng Việt trên UI có bị lỗi encoding không.
- Các màn placeholder `Reports` và `Product detail` chưa phải chức năng thật.
- QR scanner đang là UI mock, chưa quét camera thật.
- Login đang là mock, chưa validate lỗi thật.
- Các repository đều là mock data, chưa gọi API.
- Một số nút như `Xem chi tiết`, `Đổi camera`, `Thư viện ảnh`, `Đổi mật khẩu`, `Trợ giúp` chưa có nghiệp vụ thật.

Nếu tester thấy các chuỗi dạng `XÃ¡c nháº­n`, `KhÃ´ng`, `TÃ i khoáº£n`, đó là lỗi encoding và cần log bug.

## 21. Bug report format

Mỗi bug nên ghi:

```text
Bug ID:
Title:
Environment:
Build/commit:
Device/emulator:
Steps:
Expected:
Actual:
Severity:
Screenshot/video:
Log:
```

Severity gợi ý:

| Severity | Ý nghĩa |
| --- | --- |
| Critical | App crash, không login được, không mở app được |
| High | Luồng chính nhập/xuất/kiểm hỏng |
| Medium | Sai điều hướng, sai dữ liệu, filter sai |
| Low | Text sai, UI lệch nhẹ, màu/icon chưa đúng |

## 22. Definition of Done cho test vòng hiện tại

Một vòng test được xem là xong khi:

- `flutter analyze` pass.
- `flutter test` pass.
- Tester chạy hết smoke test.
- Tester chạy checklist các màn có UI thật.
- Placeholder được ghi nhận là chưa scope thật.
- Các bug được log rõ Expected/Actual.
- Các lỗi encoding nếu có được log riêng.
- Các API_SWAP được đánh dấu để regression khi nối backend.
