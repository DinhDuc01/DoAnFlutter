# Cẩm nang đọc code StockLite Mobile (theo source hiện tại)

Tài liệu này giúp đọc và bảo vệ đồ án Flutter tại `D:\DoAnFlutter`. Nội dung được tổng hợp trực tiếp từ source hiện tại, ưu tiên trả lời ba câu hỏi:

1. Khi người dùng thao tác, code chạy qua những file nào?
2. Quyền, trạng thái và API được kiểm tra ở đâu?
3. Khi có lỗi, nên bắt đầu kiểm tra từ đâu?

> Nguyên tắc cốt lõi: Flutter hiển thị và kiểm tra sớm; Backend vẫn là nguồn sự thật cuối cùng về quyền, trạng thái, tồn kho và kết quả mutation.

---

## 1. Bản đồ kiến trúc

Project dùng cách tổ chức **feature-first**:

```text
lib/
├── main.dart                    Khởi động ứng dụng
├── app/app.dart                 MaterialApp, theme, initial route
├── core/                        Hạ tầng dùng chung
│   ├── api/                     HTTP client và đọc JSON
│   ├── config/                  API base URL
│   ├── routes/                  Toàn bộ named route
│   ├── widgets/                 Permission guard, loading/error UI
│   ├── notifications/           Firebase Cloud Messaging
│   └── realtime/                SignalR và reload realtime
└── features/                    Từng nhóm nghiệp vụ
    ├── auth/                    Đăng nhập, session, quyền
    ├── thu_mua/                 Lịch và phiếu thu mua
    ├── inbound/                 Nhập kho, xếp vị trí
    ├── paddy_lots/              Lô và truy vết
    ├── quality_inspection/      Chất lượng và cách ly
    ├── kho/                     Tồn kho, kiểm kê
    ├── sales_orders/            Đơn bán
    ├── outbound_orders/         Xuất kho và giao hàng
    ├── milling/                 Xay xát
    ├── scale/                   Cân BLE
    ├── scan/                    QR/barcode
    ├── debts/                   Công nợ
    └── notifications/           Trung tâm thông báo
```

### Cấu trúc chuẩn của một feature

```text
features/<tên_feature>/
├── models/          Model Dart, parse JSON, status helper
├── data/            Repository interface/implementation, gọi API
└── presentation/
    ├── screens/     State màn hình và điều hướng
    └── widgets/     Thành phần UI nhỏ dùng lại
```

### Luồng dữ liệu chuẩn

```text
Người dùng
  → Screen/Widget
  → kiểm tra permission + status + busy
  → Repository
  → ApiClient
  → HTTP + Bearer token
  → Backend
  → JSON response
  → Model parsing
  → setState/reload
  → Loading / Empty / Success / Error UI
```

Không nên gọi HTTP trực tiếp trong widget. Repository giúp test bằng fake, gom endpoint và chuẩn hóa lỗi.

---

## 2. Luồng khởi động và đăng nhập

### File quan trọng

| File | Vai trò |
|---|---|
| `lib/main.dart` | Khởi tạo Flutter, restore session, FCM, SignalR |
| `lib/app/app.dart` | Tạo `MaterialApp`, theme và initial route |
| `lib/features/auth/data/api_auth_service.dart` | Login, refresh token, tải session |
| `lib/features/auth/data/auth_session_store.dart` | Lưu session trong RAM và SharedPreferences |
| `lib/features/auth/data/startup_session_resolver.dart` | Xác minh session cache theo fail-closed |
| `lib/features/auth/data/token_refresh_coordinator.dart` | Điều phối refresh token khi API trả 401 |
| `lib/features/auth/models/auth_session.dart` | User, role, permission và helper kiểm quyền |

### Thứ tự chạy của `main()`

```text
WidgetsFlutterBinding.ensureInitialized
→ tải cấu hình nhân vật
→ gắn callback refresh token cho ApiClient
→ AuthSessionStore.load()
→ resolveStartupSession()
→ FcmService.initApp()
→ nếu session hợp lệ: start FCM + Realtime
→ runApp(StockLiteApp)
```

### Fail-closed session

`resolveStartupSession()` xử lý như sau:

- Không có session cache → mở Login.
- Role bị cấm Mobile → dừng FCM/Realtime, xóa session, mở Login.
- `/auth/me/session` trả 401/403 hoặc session sai → xóa session.
- Lỗi mạng tạm thời → giữ cache có cấu trúc hợp lệ để app có thể mở offline.

Điểm quan trọng khi bảo vệ đồ án: app không chỉ tin token cũ; nó cố xác minh session trước khi mở Home.

### API auth chính

| Mục đích | Method/endpoint |
|---|---|
| Login | `POST /api/v1/auth/admin/login` |
| Session hiện tại | `GET /api/v1/auth/me/session` |
| Refresh token | `POST /api/v1/auth/refresh-token` |
| Logout | `POST /api/v1/auth/logout` |

---

## 3. Phân quyền: ba lớp bảo vệ

### Lớp 1 — Login/session

`AuthUser.isMobileBlocked` chặn role không được dùng Mobile. Multi-role có ít nhất một role bị cấm cũng phải bị từ chối.

### Lớp 2 — Route READ guard

`lib/core/routes/app_routes.dart` bọc route bằng `PermissionGuard`.

Ví dụ:

```dart
PermissionGuard(
  menuCode: 'QUALITY_INSPECTIONS',
  child: QualityInspectionScreen(),
)
```

Khi không truyền `action`, guard yêu cầu quyền `READ`. Không có session/quyền thì không mount feature và không gọi API feature.

### Lớp 3 — CTA và mutation function

Một nút mutation chỉ hợp lệ khi đồng thời thỏa:

```text
permission đúng
AND statusCode đúng
AND chưa busy/submitting
```

Không chỉ ẩn nút. Hàm xử lý cũng phải kiểm tra lại trước khi gọi repository để tránh gọi trực tiếp hoặc double tap.

### Action chuẩn

| ID Backend | Action |
|---:|---|
| 1001 | CREATE |
| 1002 | READ |
| 1003 | UPDATE |
| 1004 | DELETE |
| 1005 | EXPORT |
| 1006 | APPROVE |

Permission trùng `menuCode/menuId` được merge và union actions trong model session. Permission rỗng không đồng nghĩa Admin.

### Menu code đang dùng trên Mobile

| Feature | Menu code |
|---|---|
| Thu mua | `RICE_PURCHASE` |
| Nhập kho | `INBOUND_ORDERS` |
| Tồn kho | `INVENTORIES` |
| Kiểm kê | `STOCKTAKE` |
| Đơn bán | `SALE_ORDERS` |
| Xuất kho | `OUTBOUND_ORDERS` |
| Lô | `PADDY_LOTS` |
| Chất lượng | `QUALITY_INSPECTIONS` |
| Công nợ | `DEBTS` |
| Xay xát | `MILLING_ORDERS` |
| Báo cáo | `REPORTS` |
| QR resolve | `PRODUCT_VARIANTS` |

---

## 4. Điều hướng

Toàn bộ route tập trung tại `lib/core/routes/app_routes.dart`.

| Route | Screen | Guard |
|---|---|---|
| `/login` | Login | Public |
| `/home` | Home | Session hợp lệ, role không bị chặn |
| `/thu-mua` | Thu mua | `RICE_PURCHASE/READ` |
| `/nhap-kho` | Putaway | `INBOUND_ORDERS/READ` |
| `/sales-orders` | Đơn bán | `SALE_ORDERS/READ` |
| `/outbound-orders` | Xuất kho | `OUTBOUND_ORDERS/READ` |
| `/stocktake` | Kiểm kê | `STOCKTAKE/READ` |
| `/paddy-lots` | Lô | `PADDY_LOTS/READ` |
| `/quality-inspections` | Chất lượng | `QUALITY_INSPECTIONS/READ` |
| `/debts` | Công nợ | `DEBTS/READ` |
| `/xay-xat` | Xay xát | `MILLING_ORDERS/READ` |
| `/scan-qr` | Quét QR | `PRODUCT_VARIANTS/READ` |

`HomeScreen` và `HomeTodayTab` tiếp tục lọc tab/shortcut theo quyền. Route guard vẫn bắt buộc vì người dùng có thể mở route trực tiếp.

---

## 5. Core API và cách đọc response

### `ApiClient`

`lib/core/api/api_client.dart` chịu trách nhiệm:

- ghép `ApiConfig.baseUrl` với path;
- thêm `Authorization: Bearer <token>`;
- encode/decode JSON;
- timeout;
- retry giới hạn cho GET lỗi tạm thời;
- gọi refresh token khi gặp 401;
- ném exception cho HTTP lỗi thay vì coi là success.

### Envelope phổ biến

```json
{
  "status": 200,
  "code": "CMN_200",
  "message": "Success",
  "resources": {},
  "errors": null,
  "isSucceeded": true
}
```

Repository phải đọc `resources` và kiểm tra `isSucceeded/status`. Không được coi JSON parse được là nghiệp vụ thành công.

### `JsonReader`

`lib/core/api/json_reader.dart` cung cấp đọc kiểu null-safe. Nên dùng helper thay vì ép kiểu trực tiếp vì Backend có thể trả `null`, số dạng string hoặc field thiếu.

---

## 6. Các feature nghiệp vụ

### 6.1 Thu mua

**Điểm vào:**

- `thu_mua_tab.dart`: lịch, phiếu, nháp.
- `purchase_schedule_detail_screen.dart`: chi tiết lịch.
- `thu_mua_screen.dart`: tạo/sửa phiếu.
- `api_thu_mua_repository.dart`: API phiếu mua.

**Luồng:**

```text
Lịch thu mua
→ xem chi tiết
→ tạo hoặc cập nhật phiếu
→ nhập từng bao
→ repository POST/PUT
→ reload chi tiết/danh sách
```

**Quyền:** READ để xem, CREATE để tạo, UPDATE để sửa DRAFT. Status null/unknown chỉ xem.

**Điểm dễ lỗi:** khôi phục draft phải giữ từng bao riêng; không cộng nhiều bao thành một dòng. Dropdown sản phẩm phải giữ đúng variant đã lưu.

### 6.2 Nhập kho và xếp vị trí

**File:**

- `inbound_putaway_screen.dart`: danh sách lô chờ xếp.
- `inbound_putaway_line_screen.dart`: gợi ý và xác nhận vị trí.
- `inbound_order_repository.dart`: submit, start receipt, suggestion, confirm.
- `bag_putaway_planner.dart`: lập phương án nhóm bao thuần Dart.

**API chính:**

```text
GET  /api/v1/inbound-orders/putaway-pending
POST /api/v1/inbound-orders/{id}/submit
POST /api/v1/inbound-orders/{id}/receipts/start
POST /api/v1/inbound-orders/{id}/receipts/{itemId}/putaway-suggestions
POST /api/v1/inbound-orders/{id}/receipts/{itemId}/bag-putaway-plan
POST /api/v1/inbound-orders/{id}/receipts/{itemId}/select-putaway
POST /api/v1/inbound-orders/{id}/receipts/{itemId}/confirm
```

READ được xem. UPDATE mới được mutation theo status. Phiếu chờ duyệt có thể mở read-only và hiển thị lý do chờ.

### 6.3 Lô và truy vết

`paddy_lot_repository.dart` tải list, detail và traceability. UI không được tự suy ra trạng thái chất lượng từ tên hiển thị.

```text
POST /api/v1/paddy-lots/paged-advanced
GET  /api/v1/paddy-lots/{id}
GET  /api/v1/paddy-lots/{id}/traceability
```

### 6.4 Chất lượng và cách ly

**File quan trọng:**

- `quality_inspection_screen.dart`: list và filter.
- `quality_inspection_detail_screen.dart`: detail read-only/action.
- `quality_inspection_create_screen.dart`: form tạo.
- `quality_inspection_edit_screen.dart`: cập nhật.
- `quality_inspection_bag_session_screen.dart`: kiểm tra từng bao và hoàn tất phiên.
- `quality_inspection_repository.dart`: toàn bộ API.

**API chính:**

```text
POST /api/v1/quality-inspections/paged-advanced
GET  /api/v1/quality-inspections/{id}
GET  /api/v1/quality-inspections/by-lot/{lotId}
POST /api/v1/quality-inspections
PUT  /api/v1/quality-inspections
GET  /api/v1/quality-inspections/{inspectionId}/bags
PUT  /api/v1/quality-inspections/{inspectionId}/bags/{bagId}
POST /api/v1/quality-inspections/{inspectionId}/complete
```

Inspection status và Paddy Lot status là hai khái niệm khác nhau. Không dùng trạng thái lô để cấp quyền sửa phiếu kiểm tra.

### 6.5 Kiểm kê

**File:** `stock_take_list_screen.dart`, `stock_take_detail_screen.dart`, `stock_take_repository.dart`.

**State machine:**

```text
DRAFT
→ nhập số đếm + lưu
→ SUBMITTED
→ APPROVED hoặc REJECTED
```

**Quyền:** CREATE tạo; UPDATE sửa/gửi DRAFT; APPROVE duyệt/từ chối SUBMITTED; DELETE chỉ xóa status Backend cho phép.

Không dùng `statusName`; luôn normalize `statusCode`.

### 6.6 Đơn bán

**File:** `sales_order_list_screen.dart`, `sales_order_detail_screen.dart`, `sales_order_create_screen.dart`, `sales_order_repository.dart`.

**API:** list paged, detail, create, confirm, reserve, cancel, create-outbound.

Sản phẩm bán trên Mobile được lọc theo nghiệp vụ gạo/phụ phẩm; không đưa lúa thóc vào picker. Mutation yêu cầu `SALE_ORDERS/UPDATE` và status hợp lệ.

### 6.7 Xuất kho và giao hàng

**State nghiệp vụ tổng quát:**

```text
phân bổ
→ lấy hàng
→ đóng gói
→ xuất kho
→ giao hàng
→ hoàn tất/thất bại
```

Repository có endpoint allocate, pick, confirm-packing, confirm-dispatch, complete-delivery, fail-delivery và cancel. Mỗi action phải dựa trên status code và UPDATE permission.

### 6.8 Xay xát

**File quan trọng:**

- `milling_preparation_screen.dart`: list/detail và action theo status.
- `milling_create_order_screen.dart`: create/edit DRAFT.
- `milling_source_selection_screen.dart`: chọn lô/cột/bao và reserve.
- `milling_result_confirmation_screen.dart`: nhập nhiều loại đầu ra.
- `api_milling_repository.dart`: contract API.
- `milling_output_form.dart`: state/pure validation cho đầu ra.

**State machine:**

```text
DRAFT
→ reserve nguồn lúa
→ RESERVED
→ start(machineRef, operatorId)
→ IN_PROGRESS/MILLING
→ nhập RICE/BROKEN/BRAN/HUSK
→ complete
→ COMPLETED
```

**Gợi ý vị trí đầu ra:**

```text
SKU + warehouseId + requiredWeightKg
→ POST /api/v1/putaway/suggestions
→ danh sách rank/location/free capacity
→ người dùng chọn vị trí
```

Không tự gửi reserve/start/complete từ thao tác chỉ mang tính gợi ý.

### 6.9 Cân BLE

`WeightReading` phân biệt:

- parse hợp lệ về cấu trúc;
- `canApplyToWeighing`: stable, fresh, kg, finite và > 0.

`MillingWeighingPanel` không tự áp số cân khi stream thay đổi. Người dùng phải bấm áp dụng/xác nhận.

### 6.10 QR

```text
Camera/mobile_scanner
→ ScanResultInfo
→ POST /api/v1/qr/resolve
→ ResolvedQr
→ điều hướng theo loại kết quả
```

Camera chỉ được mount sau khi route qua `PRODUCT_VARIANTS/READ` guard.

### 6.11 Thông báo và realtime

- FCM báo có sự kiện.
- SignalR báo dữ liệu thay đổi.
- Screen dùng `RealtimeReloadMixin` để reload có kiểm soát.
- Thông báo cá nhân dùng `/api/v1/notification/me` và các endpoint mark-read/delete.

Realtime không thay thế GET detail. Sau mutation vẫn reload từ Backend để xác minh status thật.

---

## 7. State và vòng đời widget

Các màn chủ yếu dùng `StatefulWidget`, `Future`, `setState`, repository injection.

Mẫu an toàn:

```dart
if (_busy) return;
setState(() => _busy = true);
try {
  await repository.mutate(...);
  if (!mounted) return;
  await _reload();
} catch (error) {
  if (!mounted) return;
  // hiển thị lỗi, không success giả
} finally {
  if (mounted) setState(() => _busy = false);
}
```

Luôn kiểm tra `mounted` sau `await`. Không dùng `BuildContext` sau async nếu widget đã dispose; đây từng là nguồn màn đỏ khi đóng popup.

---

## 8. Cách đọc một màn hình bất kỳ

1. Tìm route mở màn trong `app_routes.dart`.
2. Kiểm tra `PermissionGuard` dùng menu code nào.
3. Mở screen, đọc `initState` và hàm `_load/_reload`.
4. Xác định repository được inject hay tự tạo.
5. Mở repository để xem endpoint, method, body và token.
6. Mở model để xem key JSON và fallback null.
7. Tìm getter `can...`, `_can...`, status normalization.
8. Tìm mọi hàm mutation và kiểm tra permission/status/busy.
9. Tìm test cùng tên feature để xem behavior được bảo vệ.

Lệnh tìm nhanh:

```powershell
rg -n "TênClass|tênEndpoint|statusCode|hasPermission" lib test
```

---

## 9. Hệ thống test

| Nhóm | Ý nghĩa |
|---|---|
| `*_repository_test.dart` | Endpoint, body, token, parse, HTTP error |
| `*_permission_test.dart` | Quyền và status CTA |
| `*_flow_test.dart` | Điều hướng và chuỗi nghiệp vụ |
| `*_screen_test.dart` | Loading/empty/error/success/widget behavior |
| `integration_test/` | Smoke test gần runtime thật |

Nguyên tắc test:

- fake repository/API client, không gọi production;
- không sửa expected chỉ để PASS;
- mutation phải kiểm tra số lần gọi;
- dialog mở/hủy không được gọi API;
- test null/unknown status theo fail-closed;
- tránh `pumpAndSettle` vô hạn với stream/realtime.

Lệnh xác minh cơ bản:

```powershell
D:\flutter\bin\flutter.bat analyze --no-pub
D:\flutter\bin\flutter.bat test --no-pub -r expanded
```

---

## 10. Các điểm phải đặc biệt cẩn thận

### 10.1 Status code

Quyền thao tác phải dựa trên `statusCode.trim().toUpperCase()`, không dựa vào `statusName` tiếng Việt. Unknown/null luôn read-only.

### 10.2 Dropdown edit

`DropdownButtonFormField.value` phải xuất hiện đúng một lần trong `items`. Khi edit, item hiện tại có thể không còn trong page/filter; cần ghép detail hiện tại vào options hoặc dùng fallback an toàn.

### 10.3 Constraint vô hạn

Button theme dùng chiều cao chung có thể tạo width vô hạn trong `Row` nằm trong scroll ngang. Khi đặt button ở vùng unconstrained, phải giới hạn width cục bộ.

### 10.4 Async popup/navigation

Sau khi popup đóng, callback async không được dùng context đã dispose. Controller/focus/stream phải dispose đúng owner.

### 10.5 Double-submit

Disable UI là chưa đủ. Hàm mutation phải bắt đầu bằng guard `_busy` và chỉ reset trong `finally`.

### 10.6 API suggestion

Gợi ý phụ thuộc đúng warehouse, productVariant, requiredWeight và config Backend. Không fallback sang toàn bộ location nếu suggestion rỗng, vì sẽ phá nghiệp vụ xếp kho.

### 10.7 Encoding

Một số comment/tài liệu cũ đang có dấu hiệu mojibake (`Ã`, `Ä`, `á»`). Không copy các chuỗi lỗi này sang UI. File mới phải lưu UTF-8.

### 10.8 Git

Project có nhiều nhánh và commit lớn. Trước khi sửa:

```powershell
git status --short --branch
git log --oneline -5
```

Không reset/xóa thay đổi khi chưa xác định chúng thuộc ai. Khi cần lấy một commit từ nhánh khác, ưu tiên backup branch rồi cherry-pick.

---

## 11. Câu trả lời ngắn khi bảo vệ đồ án

### Vì sao dùng repository?

Để tách UI khỏi HTTP, gom contract/parsing, dễ fake trong test và tránh nhiều màn tự tạo request khác nhau.

### Vì sao phải guard ở cả route và nút?

Route guard ngăn tải feature không có READ. CTA guard ngăn thao tác sai quyền. Function guard chống gọi mutation qua callback trực tiếp hoặc double tap. Backend vẫn xác thực lần cuối.

### Vì sao reload detail sau mutation?

Response mutation không luôn chứa toàn bộ trạng thái mới. GET detail xác nhận Backend đã chuyển đúng status và tránh UI tự giả định thành công.

### Vì sao null/unknown status chỉ xem?

Fail-closed an toàn hơn: khi contract thay đổi hoặc parse thiếu, Mobile không được tự cấp quyền mutation.

### FCM và SignalR khác nhau thế nào?

FCM phù hợp thông báo kể cả khi app nền; SignalR cập nhật realtime khi app đang kết nối. Cả hai chỉ kích hoạt reload, không thay Backend detail.

### Cân IoT được bảo vệ thế nào?

Reading chỉ được áp dụng khi ổn định, còn mới, đúng kg, hữu hạn và lớn hơn 0; thay đổi stream không tự ghi đè form nếu người dùng chưa xác nhận.

---

## 12. Thứ tự học source đề xuất

1. `main.dart` và `app.dart`.
2. `auth_session.dart`, `auth_session_store.dart`, `startup_session_resolver.dart`.
3. `api_client.dart`, `json_reader.dart`.
4. `app_routes.dart`, `permission_guard.dart`.
5. Một feature đơn giản: `debts` hoặc `paddy_lots`.
6. Feature có mutation/status: `stock_take` hoặc `sales_orders`.
7. Feature phức tạp: `inbound`, `quality_inspection`, `milling`.
8. `scale`, `scan`, `notifications`, `realtime`.
9. Đọc test song song với từng feature.

Nếu chỉ có 15 phút trước khi trình bày, hãy nhớ chuỗi sau:

```text
Session → Permission → Route → Screen → Repository → ApiClient
→ Backend → Model → Reload → UI
```

