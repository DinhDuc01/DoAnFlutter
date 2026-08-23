# CẨM NANG ĐỌC CODE VÀ BẢO VỆ ĐỒ ÁN STOCKLITE MOBILE

> Tài liệu này giải thích code Flutter trong `D:\DoAnFlutter` theo hướng bảo vệ đồ án: kiến trúc, luồng dữ liệu, phân quyền, API, trạng thái nghiệp vụ, xử lý lỗi, kiểm thử và các câu hỏi phản biện khó. Nội dung bám theo source hiện tại, không mô tả chức năng chưa tồn tại như thể đã hoàn thành.

---

## 1. Bài toán mà ứng dụng giải quyết

StockLite Mobile hỗ trợ các thao tác hiện trường trong chuỗi cung ứng lúa gạo:

- đăng nhập và nhận quyền từ Backend;
- lập/xem lịch và phiếu thu mua;
- nhập kho, chọn vị trí lưu kho;
- quản lý lô và truy vết;
- kiểm định chất lượng/cách ly;
- kiểm kê kho;
- lập và xử lý đơn bán;
- xuất kho/giao hàng;
- công nợ;
- xay xát và cân;
- quét QR, thông báo và realtime.

Ứng dụng Mobile không tự quyết định nghiệp vụ cuối cùng. Backend vẫn là nguồn sự thật đối với:

- quyền người dùng;
- trạng thái chứng từ;
- tồn kho và khối lượng khả dụng;
- dữ liệu lô/bao/vị trí;
- kết quả của mutation;
- xung đột đồng thời.

### Thông điệp nên dùng khi bảo vệ

> Flutter chịu trách nhiệm hiển thị, thu thập dữ liệu, validation sớm và điều phối luồng. Backend chịu trách nhiệm xác thực lại quyền, trạng thái và tính toàn vẹn nghiệp vụ.

---

## 2. Kiến trúc tổng thể

Project tổ chức theo **feature-first**, mỗi nghiệp vụ có model, repository và presentation riêng.

```text
lib/
├── app/                         Cấu hình MaterialApp
├── core/
│   ├── api/                     HTTP client, JSON reader
│   ├── routes/                  Route tập trung
│   ├── theme/                   Theme và màu dùng chung
│   ├── widgets/                 Permission guard, UI state dùng chung
│   ├── realtime/                Realtime reload
│   └── notifications/           FCM
└── features/
    ├── auth/
    ├── thu_mua/
    ├── inbound/
    ├── paddy_lots/
    ├── quality_inspection/
    ├── kho/
    ├── sales_orders/
    ├── outbound_orders/
    ├── milling/
    ├── scale/
    └── ...
```

### Luồng chung của một feature

```text
Screen/Widget
    ↓ gọi interface
Repository
    ↓ gọi HTTP
ApiClient
    ↓ Bearer token + JSON
Backend endpoint
    ↓ response envelope
Model parsing
    ↓
State của Screen
    ↓
Loading / Success / Empty / Error / Forbidden UI
```

### Tại sao không gọi API trực tiếp từ Widget?

Repository giúp:

1. tách giao diện khỏi chi tiết endpoint;
2. thay API thật bằng fake repository trong widget test;
3. gom parsing và error mapping;
4. tránh lặp request body ở nhiều màn;
5. làm trace nghiệp vụ rõ ràng.

---

## 3. Điểm bắt đầu của ứng dụng

### `lib/main.dart`

Trình tự khởi động:

```text
WidgetsFlutterBinding.ensureInitialized
→ tải cấu hình nhân vật
→ gắn callback refresh token cho ApiClient
→ AuthSessionStore.load
→ resolveStartupSession
→ khởi tạo Firebase
→ nếu session hợp lệ: bật FCM + Realtime
→ runApp
```

Điểm quan trọng là app **không chỉ tin session cache**. `resolveStartupSession` xác minh session trước khi mở Home.

### Fail-closed session

Khi phiên bị Backend từ chối (401/403/token hết hạn):

- xóa session cũ;
- không tiếp tục dùng permission cache;
- dừng notification/realtime của user;
- trở về Login;
- không mở Home.

Với lỗi mạng tạm thời, code cần phân biệt với lỗi xác thực để tránh đăng xuất người dùng không cần thiết.

### `lib/app/app.dart`

`StockLiteApp` tạo `MaterialApp`, đăng ký:

- light/dark theme;
- navigator key;
- scaffold messenger key;
- initial route Login hoặc Home;
- route map tập trung từ `AppRoutes`.

---

## 4. HTTP và API contract

### `lib/core/api/api_client.dart`

`ApiClient` hỗ trợ:

- GET, POST, PUT, PATCH, DELETE;
- query parameters;
- JSON body;
- Bearer token;
- timeout;
- retry giới hạn cho GET lỗi tạm thời;
- refresh access token khi gặp 401;
- mapping HTTP lỗi thành `ApiException`.

### Vì sao chỉ GET được retry tự động?

GET thường là idempotent. Nếu retry POST/PUT/DELETE không kiểm soát, cùng một mutation có thể bị thực hiện hai lần. Vì vậy mutation được bảo vệ ở UI bằng `_busy`/`_submitting`, còn Backend vẫn phải đảm bảo idempotency hoặc conflict handling nếu contract yêu cầu.

### Response thành công

Không được kết luận thành công chỉ vì request không throw. Repository phải xem:

- HTTP status nằm trong 2xx;
- `isSucceeded` nếu envelope có field này;
- dữ liệu `resources` đúng cấu trúc;
- với mutation trạng thái: reload detail và xác minh status mới.

### HTTP status thường gặp

| Status | Ý nghĩa ở Mobile |
|---:|---|
| 200/201 | Request thành công, vẫn cần parse/verify body |
| 400/422 | Dữ liệu hoặc validation nghiệp vụ sai |
| 401 | Token không hợp lệ/hết hạn; thử refresh đúng một lần |
| 403 | Đã đăng nhập nhưng thiếu quyền |
| 404 | Không còn dữ liệu hoặc endpoint/id không tồn tại |
| 409 | Xung đột đồng thời hoặc trạng thái đã đổi |
| 500+ | Lỗi server, không được hiển thị success giả |

---

## 5. Session, role và permission

### Các model chính

- `AuthSession`: access token, refresh token, user.
- `AuthUser`: thông tin user, roles, menus, permissions.
- `UserRole`: `id`, `code`, `name`.
- `UserPermission`: `menuId`, `menuCode`, tập action.

### Chuẩn hóa action

Backend có thể trả action code hoặc ID. Flutter chuẩn hóa:

| ID | Action |
|---:|---|
| 1001 | CREATE |
| 1002 | READ |
| 1003 | UPDATE |
| 1004 | DELETE |
| 1005 | EXPORT |
| 1006 | APPROVE |

Mã menu/action được trim và uppercase để tránh sai do khác chữ hoa/thường.

### Merge permission

Nếu Backend trả nhiều record cùng `menuCode` hoặc `menuId`, app phải union các action thay vì lấy record đầu. Ví dụ:

```text
SALE_ORDERS + READ
SALE_ORDERS + CREATE
SALE_ORDERS + UPDATE
```

phải thành:

```text
SALE_ORDERS → {READ, CREATE, UPDATE}
```

Nếu không merge, user có quyền thật nhưng UI có thể bị ẩn chức năng.

### Ba lớp bảo vệ quyền

1. **Navigation visibility**: tab/shortcut không có READ sẽ bị ẩn.
2. **Route guard**: gọi route trực tiếp vẫn bị chặn.
3. **Mutation function guard**: dù callback bị gọi trực tiếp, function vẫn kiểm tra quyền và status trước repository.

> Ẩn nút không phải bảo mật. Backend authorization vẫn là lớp cuối cùng.

### `PermissionBuilder`

Dùng để ẩn/hiện một widget theo menu/action.

```dart
PermissionBuilder(
  menuCode: 'STOCKTAKE',
  action: 'CREATE',
  child: FloatingActionButton(...),
)
```

### `PermissionGuard`

Dùng bảo vệ toàn màn/route. Khi không truyền action, screen guard yêu cầu **READ rõ ràng**, không chấp nhận việc user chỉ có CREATE/UPDATE.

```dart
PermissionGuard(
  menuCode: 'SALE_ORDERS',
  child: SalesOrderListScreen(),
)
```

### Permission và status phải đi cùng nhau

```text
canMutate = hasPermission(menu, action)
            AND statusCode thuộc tập trạng thái cho phép
            AND !busy
```

Unknown/null status luôn fail-closed: chỉ xem.

---

## 6. Route và điều hướng

### `lib/core/routes/app_routes.dart`

Route được định nghĩa tập trung, ví dụ:

- `/home`;
- `/thu-mua`;
- `/sales-orders`;
- `/outbound-orders`;
- `/stocktake`;
- `/quality-inspections`;
- `/paddy-lots`;
- `/xay-xat`;
- `/scan-qr`.

`/home` kiểm tra:

- session tồn tại;
- access token không rỗng;
- user không thuộc rule Mobile bị chặn.

Route feature được bọc `PermissionGuard` theo menu tương ứng.

### Bottom navigation động

`HomeScreen` chỉ đưa section vào `_sections` khi user có READ phù hợp:

- Thu mua: `RICE_PURCHASE + READ`;
- Kho: `INVENTORIES + READ`;
- Xuất kho: `OUTBOUND_ORDERS + READ`.

Thông báo và Tài khoản là section riêng theo policy hiện tại.

### Back trên Android

`PopScope` xử lý:

- đang ở tab con → quay về tab Home;
- đang ở Home → hiện dialog xác nhận thoát;
- không để thao tác back/edge swipe vô tình đóng app ngay.

---

## 7. Các luồng nghiệp vụ chính

## 7.1 Thu mua

Các thành phần quan trọng:

- `ThuMuaScreen`;
- `PurchaseScheduleDetailScreen`;
- `ApiThuMuaRepository`;
- model lịch và phiếu mua.

Luồng khái quát:

```text
Danh sách lịch/phiếu
→ xem chi tiết
→ tạo hoặc cập nhật Draft nếu có quyền
→ validation sản phẩm/giống/khối lượng
→ repository
→ Backend
→ reload dữ liệu
```

Quyền:

- READ: xem;
- CREATE: tạo;
- UPDATE + DRAFT: sửa;
- unknown/non-DRAFT: chỉ xem.

Điểm từng được xử lý kỹ:

- nhiều bao phải giữ riêng, không cộng thành một bao;
- draft phải load lại ghi chú và sản phẩm cụ thể;
- độ ẩm bị ẩn theo yêu cầu UI;
- wording Mobile không được thể hiện Mobile có quyền chốt nếu nghiệp vụ chỉ cho cập nhật.

## 7.2 Nhập kho và Putaway

Putaway là việc đề xuất/chọn vị trí nhập kho phù hợp.

```text
Chọn SKU + kho + khối lượng
→ POST /api/v1/putaway/suggestions
→ Backend chấm điểm vị trí
→ Mobile hiển thị danh sách gợi ý
→ người dùng chọn/xác nhận
```

Các tiêu chí Backend có thể dùng:

- sức chứa còn lại;
- occupancy;
- cùng loại sản phẩm;
- độ ưu tiên vị trí;
- kho đúng với chứng từ;
- cách ly/active status.

Mobile không nên tự tính một thuật toán putaway khác. Nếu Web và Mobile khác kết quả, phải so request body, base URL và parsing response trước.

## 7.3 Lô và truy vết

Luồng đọc:

```text
PaddyLot list
→ detail
→ traceability
→ lịch sử nguồn, vị trí, bao, chứng từ liên quan
```

Route yêu cầu `PADDY_LOTS + READ`. QR scanner được guard trước khi mount camera.

## 7.4 Chất lượng và cách ly

Tách hai khái niệm:

- **Inspection status**: trạng thái phiếu kiểm định;
- **Lot status**: trạng thái của lô.

Không được dùng trạng thái lô để suy ra phiếu kiểm định đang Draft. CTA mutation phải dựa vào permission và inspection status đúng contract.

## 7.5 Kiểm kê kho

Luồng cơ bản:

```text
Tạo phiếu
→ nhập số đếm
→ lưu Draft
→ gửi duyệt
→ Submitted
→ Approve hoặc Reject
→ Approved/Rejected read-only
```

Delete chỉ áp dụng khi Backend và status cho phép, hiện theo flow đã kiểm tra là Draft + DELETE.

Các lỗi UI cần tránh:

- input khởi tạo `0` rồi append thành `010`;
- mutation CTA xuất hiện ở status read-only;
- double tap gửi hai request;
- PUT thành công nhưng reload chưa đổi status vẫn báo success.

## 7.6 Đơn bán

Luồng chính:

```text
Danh sách
→ tạo đơn
→ chọn khách, kho, SKU, số lượng, giá
→ POST tạo đơn
→ NEW
→ xác nhận
→ giữ hàng
→ tạo outbound
→ xuất/giao
```

CTA phụ thuộc `SALE_ORDERS + UPDATE` và status hợp lệ. Completed/Cancelled/unknown chỉ xem.

### Quy tắc SKU khi tạo đơn

Endpoint product variant trả cả nguyên liệu đầu vào. Mobile hiện lọc theo metadata Backend:

```text
productCategoryId == 101 (Lúa thô) → loại khỏi picker Đơn bán
```

Không lọc theo tên `LUA`, `GAO`, `RICE` vì tên là dữ liệu hiển thị, có thể thay đổi và dễ lọc nhầm. Gạo thành phẩm và phụ phẩm vẫn được giữ.

Defense-in-depth tại form cũng chặn submit nếu một SKU lúa thô lọt vào từ state cũ.

## 7.7 Xuất kho và giao hàng

Đơn bán và phiếu xuất là hai bounded context khác nhau:

- Đơn bán mô tả cam kết bán cho khách;
- Outbound mô tả lấy hàng, đóng gói, xuất kho và giao hàng thực tế.

Do đó không nên gộp UI khiến người dùng tưởng tạo đơn là đã xuất kho.

## 7.8 Xay xát

State machine khái quát:

```text
DRAFT
→ chọn lô/cột/bao
→ Reserve
→ RESERVED
→ nhập mã máy + chọn người vận hành
→ Start
→ IN_PROGRESS/MILLING
→ nhập output
→ Complete (chỉ khi contract và validation đầy đủ)
```

### Reserve

- gợi ý nguồn không được tự Reserve;
- người dùng review bao;
- reserve body dùng Columns/locationId và bagIds đúng contract;
- 409 nghĩa là dữ liệu có thể vừa bị lệnh khác giữ;
- Start là bước riêng.

### Start

Trước Start cần:

- mã máy xay;
- người vận hành hợp lệ;
- status mới nhất là RESERVED;
- permission phù hợp;
- chống double-submit.

### Output

Các loại output:

- RICE: gạo;
- BROKEN: tấm;
- BRAN: cám;
- HUSK: trấu.

Mỗi output có state độc lập:

- SKU;
- location;
- bagCount;
- kg/bag;
- outputWeightKg.

SKU phải lọc theo category/metadata thật, không đoán tên. Location nên lấy từ Putaway Suggestions của Backend, không cho chọn tùy ý toàn kho nếu nghiệp vụ yêu cầu gợi ý.

### Cân IoT

`WeightReading` phân biệt:

- parse được cấu trúc;
- đủ điều kiện áp dụng vào form.

Reading chỉ được apply khi:

- finite;
- > 0;
- unit kg;
- stable;
- fresh, không stale.

Stream cân thay đổi không tự ghi đè form. Người dùng phải bấm áp dụng/xác nhận.

---

## 8. Quản lý state và vòng đời Widget

Project chủ yếu dùng state cục bộ của `StatefulWidget` kết hợp Repository injection.

Mẫu thường gặp:

```dart
bool _loading = true;
bool _submitting = false;
Object? _error;
List<Model> _items = const [];
```

### Quy tắc async an toàn

```dart
final result = await repository.load();
if (!mounted) return;
setState(() { ... });
```

Điều này tránh `setState after dispose` khi người dùng rời màn trước khi API trả về.

### Chống double-submit

```dart
if (_submitting) return;
setState(() => _submitting = true);
try {
  await repository.mutate();
} finally {
  if (mounted) setState(() => _submitting = false);
}
```

Function vẫn phải kiểm tra permission/status; disabled button chỉ là lớp UX.

---

## 9. UI state bắt buộc

Một màn API tốt không chỉ có Success. Cần phân biệt:

- Initial/loading;
- Refreshing;
- Empty;
- Search empty;
- Error;
- Retry;
- Unauthorized;
- Forbidden;
- Success;
- Mutation loading;
- Conflict/validation error.

Mobile layout cần:

- `SafeArea`;
- tránh button nhận infinite width trong horizontal scroll;
- bottom action không che ListView;
- dropdown value phải tồn tại đúng một lần trong items;
- expandable section phải có state rõ ràng;
- không dùng bảng Web ngang trên màn 360–390dp.

---

## 10. Realtime, FCM và refresh

FCM dùng cho push notification. Realtime dùng để yêu cầu màn reload khi dữ liệu liên quan thay đổi.

Nguyên tắc:

- chỉ start sau khi session hợp lệ;
- stop khi logout/session bị từ chối;
- widget test phải inject/no-op service, không mở kết nối thật;
- realtime event không được tự thực hiện mutation;
- refresh không được làm mất search/filter state nếu UX yêu cầu giữ.

---

## 11. Chiến lược kiểm thử

### Pure/model tests

Kiểm tra:

- parse JSON;
- null safety;
- calculation;
- status normalization;
- validation;
- upsert immutable list.

### Repository tests

Dùng `FakeApiClient` để xác minh:

- method/path/query;
- Bearer token;
- request body;
- response parsing;
- 4xx/5xx không thành success;
- không gọi HTTP thật.

### Widget tests

Dùng fake repository/session để kiểm tra:

- loading/empty/error/success;
- permission/status CTA;
- dialog cancel không mutation;
- double-submit;
- navigation;
- reload sau mutation;
- không overflow ở viewport nhỏ.

### Regression tests

Project có test theo feature, ví dụ:

- auth và permission;
- Thu mua;
- inbound putaway;
- stock take;
- sales order;
- quality inspection;
- milling;
- scale/weight reading;
- QR;
- realtime.

### Lệnh kiểm tra

```powershell
Set-Location D:\DoAnFlutter
$env:JAVA_HOME='D:\UnityEditor\6000.3.13f1\Editor\Data\PlaybackEngines\AndroidPlayer\OpenJDK'
$env:PATH="$env:JAVA_HOME\bin;D:\Android\platform-tools;$env:PATH"
$env:PUB_CACHE='D:\PubCache'

D:\flutter\bin\flutter.bat analyze --no-pub
D:\flutter\bin\flutter.bat test --no-pub -r expanded
```

Không nối hai lệnh Flutter vào cùng chuỗi sau `-r expanded`, vì PowerShell sẽ hiểu nhầm toàn bộ phần sau là giá trị reporter.

---

## 12. Những quyết định kỹ thuật đáng bảo vệ

### 12.1 Backend là nguồn sự thật

Flutter có guard để UX và giảm request sai, nhưng không tuyên bố UI guard thay thế Backend authorization.

### 12.2 Fail-closed

Khi role, permission hoặc status không rõ:

- cho phép xem nếu có READ rõ ràng;
- không hiển thị mutation;
- không suy đoán quyền từ role name;
- không suy đoán Draft từ status label.

### 12.3 Không hardcode ID nghiệp vụ tùy tiện

ID chỉ được dùng khi đó là seed/contract đã xác nhận. Ví dụ category `101 = Lúa thô` được dùng để loại nguyên liệu khỏi SKU picker Đơn bán. Không dùng ID 0 làm fallback để gửi API.

### 12.4 Không fake dữ liệu runtime

Fake chỉ dùng trong test. Runtime phải lấy lookup từ API thật và hiển thị loading/error/empty.

### 12.5 Không retry mutation tùy tiện

Tránh tạo chứng từ hoặc thay đổi trạng thái hai lần.

---

## 13. Điểm còn hạn chế cần trả lời trung thực

1. `flutter analyze` hiện vẫn có một số warning/info cũ, chủ yếu deprecation, const và dead code legacy; không đồng nghĩa compile fail nhưng cần backlog cleanup.
2. Một số nghiệp vụ phụ thuộc contract Backend đang phát triển; Mobile không nên tự suy đoán.
3. FCM/realtime và BLE cần runtime verification trên thiết bị thật ngoài widget test.
4. UI guard không thay thế kiểm tra quyền phía Backend.
5. Web và Mobile có thể khác UI, nhưng request contract và state transition phải thống nhất.

Trả lời tốt:

> Em phân loại phần nào đã có test tự động, phần nào mới được xác minh runtime, và phần nào cần Backend handoff. Em không coi một test pass là bằng chứng cho toàn bộ hệ thống production.

---

## 14. Bộ câu hỏi phản biện khó và cách trả lời

### Câu 1: Vì sao không dùng Bloc/Riverpod?

Project dùng Repository injection và state cục bộ vì phạm vi màn hình hiện tại phù hợp, giảm chi phí chuyển đổi architecture. Repository vẫn đảm bảo testability. Nếu độ phức tạp state liên màn tăng, có thể chuyển controller/state management theo từng feature mà không đổi API layer.

### Câu 2: Nếu ẩn nút theo permission thì hacker vẫn gọi API được?

Đúng. UI guard không phải bảo mật cuối. Nó giúp UX và ngăn thao tác vô ý. Backend phải kiểm tra token, menu/action, ownership, warehouse scope và status trước mutation.

### Câu 3: Tại sao unknown status lại chỉ xem?

Đây là fail-closed. Khi Mobile chưa hiểu trạng thái mới từ Backend, cho mutation có thể phá state machine. Chỉ xem an toàn hơn cho đến khi contract được cập nhật.

### Câu 4: Tại sao cần reload detail sau mutation?

Response mutation có thể không chứa toàn bộ dữ liệu tính toán. Backend có thể cập nhật status, timestamp, cost hoặc inventory. Reload đảm bảo UI hiển thị nguồn sự thật mới, không tự dựng success state.

### Câu 5: Nếu PUT thành công nhưng GET vẫn status cũ?

Không nên báo hoàn tất nghiệp vụ ngay. Có thể do eventual consistency, transaction lỗi hoặc contract mismatch. UI báo chưa xác minh được trạng thái và cho refresh/retry phù hợp, không gửi lại mutation tự động.

### Câu 6: Vì sao lọc lúa thô theo category ID thay vì tên?

Tên và SKU là dữ liệu hiển thị, có thể đổi ngôn ngữ hoặc convention. `productCategoryId` là metadata contract. Lọc theo tên dễ false positive/negative.

### Câu 7: Vì sao GET được retry nhưng POST không?

GET idempotent; POST có thể tạo bản ghi trùng. Mutation cần idempotency key hoặc contract rõ trước khi retry.

### Câu 8: Double-submit được xử lý thế nào?

UI disable nút khi `_busy`, function kiểm tra `_busy` lần nữa, test double tap chỉ cho một repository call. Backend vẫn nên xử lý conflict/idempotency.

### Câu 9: Vì sao Putaway phải dùng API gợi ý?

Backend có toàn cảnh sức chứa, occupancy, cùng sản phẩm, priority và trạng thái vị trí. Nếu Mobile tự tính, thuật toán có thể lệch Web và dữ liệu mới nhất.

### Câu 10: Làm sao biết Mobile không gửi token ra log?

Code chỉ đặt token vào Authorization header. Báo cáo/test không in token. Khi thu log runtime phải lọc dữ liệu nhạy cảm và không paste Bearer token.

### Câu 11: Nếu refresh token đồng thời từ nhiều request thì sao?

`TokenRefreshCoordinator` tồn tại để phối hợp refresh và tránh nhiều request cùng refresh. ApiClient chỉ retry request 401 một lần với token mới, tránh vòng lặp.

### Câu 12: Tại sao cần `mounted` sau await?

Widget có thể đã bị dispose khi request trả về. Gọi `setState` lúc đó gây exception. `mounted` xác nhận State còn trong widget tree.

### Câu 13: Làm sao test mà không gọi production?

Inject fake repository hoặc FakeApiClient. Test quan sát call path/body/count trong bộ nhớ. Base URL fake và không có HTTP thật.

### Câu 14: Realtime có gây reload vô hạn không?

Event chỉ yêu cầu reload read-state, không mutation. Mixin/service cần debounce/subscription lifecycle và hủy listener khi dispose. Test phải tránh service nền thật.

### Câu 15: BLE reading stable nhưng stale thì sao?

Không apply. Stable chỉ nói cân đang ổn định tại thời điểm đọc; stale nghĩa dữ liệu đã cũ. `canApplyToWeighing` yêu cầu đồng thời stable, fresh, kg, finite và > 0.

### Câu 16: Tại sao pending và confirmed weight phải tách?

Giá trị người dùng đang nhập có thể thay đổi. Chỉ confirmed mới được dùng cho summary/bước tiếp theo. Nếu pending khác confirmed, UI yêu cầu xác nhận lại.

### Câu 17: Nếu user có UPDATE nhưng không READ?

Không được mở route list/detail. Screen guard yêu cầu READ rõ ràng. Permission mutation không ngầm cấp quyền đọc.

### Câu 18: Vì sao permission phải merge?

Backend có thể trả nhiều record cho cùng menu theo role hoặc menu tree. Nếu chỉ lấy record đầu sẽ làm mất action, gây UI rỗng dù user có quyền.

### Câu 19: Vì sao Mobile và Web có thể khác layout?

Web phù hợp bảng và modal rộng; Mobile cần card, full-screen flow, bottom action và SafeArea. Khác presentation nhưng không được khác API contract/state machine.

### Câu 20: Nếu hội đồng yêu cầu chứng minh một flow?

Trình bày theo chuỗi:

```text
User action
→ Widget callback
→ permission/status validation
→ repository method
→ HTTP method/path/body/token
→ Backend response
→ model parsing
→ reload state
→ UI result
→ targeted test chứng minh
```

---

## 15. Kịch bản demo bảo vệ đề xuất

### Demo 1 — Phân quyền

1. Login bằng user có quyền giới hạn.
2. Chỉ ra bottom tabs bị lọc theo READ.
3. Thử route trực tiếp và cho thấy PermissionDenied.
4. Mở detail read-only và chỉ ra CTA mutation bị ẩn.

### Demo 2 — Đơn bán

1. Mở Tạo đơn bán.
2. Chọn khách và kho.
3. Mở SKU picker.
4. Chứng minh SKU Lúa thô không xuất hiện; Gạo/Tấm/Cám/Trấu vẫn tồn tại nếu Backend trả về.
5. Tạo đơn test nếu môi trường cho phép mutation.

### Demo 3 — Putaway

1. Chọn SKU và khối lượng.
2. Gọi gợi ý.
3. Giải thích vị trí ưu tiên dựa trên response Backend.
4. Không tự chọn vị trí giả nếu response rỗng.

### Demo 4 — Kiểm kê

1. Draft cho nhập số đếm.
2. Lưu và gửi duyệt.
3. Submitted khóa chỉnh sửa.
4. User có APPROVE mới thấy Duyệt/Từ chối.

### Demo 5 — Xử lý lỗi

1. Mô phỏng API lỗi bằng fake test hoặc tắt mạng thử nghiệm.
2. Chỉ ra Error/Retry.
3. Chứng minh dữ liệu form không bị mất và không báo success giả.

---

## 16. Checklist trước ngày bảo vệ

- [ ] `flutter analyze --no-pub` không có compile error mới.
- [ ] Targeted tests của flow demo PASS.
- [ ] Không để token/mật khẩu trong terminal, ảnh hoặc source.
- [ ] Kiểm tra đúng API base URL.
- [ ] Thiết bị thật kết nối và app dùng đúng build mới.
- [ ] Có tài khoản demo cho từng role nhưng không ghi mật khẩu vào tài liệu.
- [ ] Chuẩn bị dữ liệu read-only để demo nếu không được mutation production.
- [ ] Biết rõ endpoint/method/body của flow sẽ trình bày.
- [ ] Biết trạng thái trước/sau mutation.
- [ ] Có phương án khi mạng/Backend lỗi.
- [ ] Không tuyên bố phần chưa runtime verify là hoàn tất production.

---

## 17. Cách tự đọc một feature mới trong project

1. Tìm route vào feature trong `app_routes.dart`.
2. Tìm screen list/detail/create.
3. Tìm interface repository.
4. Tìm `Api...Repository` implementation.
5. Ghi endpoint, method, query/body.
6. Tìm model `fromJson/toJson`.
7. Tìm status helper và permission check.
8. Tìm `_busy`, error handling và reload.
9. Tìm test cùng tên feature.
10. Viết lại trace Screen → API → State → UI bằng lời của mình.

Nếu bạn làm được 10 bước này mà không nhìn tài liệu, bạn đã đủ khả năng trả lời phần lớn câu hỏi đọc code trong buổi bảo vệ.

---

## 18. Kết luận ngắn để trình bày

> StockLite Mobile được tổ chức feature-first, dùng Repository tách UI khỏi REST API, session fail-closed và permission guard ba lớp. Các mutation phụ thuộc đồng thời permission, status và busy state; Backend vẫn là nguồn sự thật. Project có model/repository/widget tests bằng fake dependency để không gọi production. Những luồng nhạy cảm như putaway, reserve, cân IoT và state transition được thiết kế theo hướng người dùng xác nhận rõ ràng, không tự động thực hiện mutation nguy hiểm.

