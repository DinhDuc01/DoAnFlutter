# Tổ chức code Tuấn Mây Mobile

Tài liệu này mô tả cấu trúc source hiện tại và vị trí cần đặt code khi phát triển thêm chức năng.

## 1. Kiến trúc tổng quát

Project được tổ chức theo hướng `feature-first`:

```text
lib/
├── main.dart
├── app/
│   └── app.dart
├── core/
│   ├── api/
│   │   ├── api_client.dart
│   │   └── json_reader.dart
│   ├── config/
│   │   └── api_config.dart
│   ├── routes/
│   │   └── app_routes.dart
│   ├── theme/
│   └── widgets/
└── features/
    ├── account/
    ├── auth/
    ├── giao_hang/
    ├── history/
    ├── home/
    ├── kho/
    ├── milling/
    ├── notifications/
    ├── products/
    ├── reports/
    ├── scan/
    └── thu_mua/
```

## 2. Trách nhiệm từng khu vực

| Khu vực | Trách nhiệm |
| --- | --- |
| `main.dart` | Điểm bắt đầu, chỉ gọi `runApp`. |
| `app/app.dart` | Khởi tạo `MaterialApp`, theme và route toàn ứng dụng. |
| `core/api` | Gửi request HTTP, đọc JSON và chuẩn hóa lỗi API. |
| `core/config` | Chứa cấu hình dùng chung như `API_BASE_URL`. |
| `core/routes` | Khai báo tên route và ánh xạ route sang màn hình. |
| `core/theme` | Màu sắc, light/dark theme và điều khiển theme. |
| `core/widgets` | Widget trạng thái và widget dùng từ hai feature trở lên. |
| `features` | Code nghiệp vụ được chia theo từng chức năng. |

## 3. Cấu trúc một feature

```text
features/<feature>/
├── data/
│   ├── <feature>_repository.dart
│   └── api_<feature>_repository.dart
├── models/
│   └── <feature_model>.dart
└── presentation/
    ├── screens/
    └── widgets/
```

- `data`: interface repository và lớp kết nối API. Widget không tự tạo `HttpClient`.
- `models`: model dùng trong mobile, không truyền `Map<String, dynamic>` vào UI.
- `presentation/screens`: quản lý trạng thái màn hình, điều hướng và gọi repository.
- `presentation/widgets`: thành phần giao diện nhỏ, nhận dữ liệu qua constructor.

Ví dụ feature Thu mua:

```text
features/thu_mua/
├── data/
│   ├── purchase_schedule_repository.dart
│   ├── thu_mua_repository.dart
│   └── api_thu_mua_repository.dart
├── models/
│   ├── purchase_schedule.dart
│   └── thu_mua_receipt.dart
└── presentation/
    ├── screens/
    │   ├── purchase_schedule_detail_screen.dart
    │   ├── thu_mua_screen.dart
    │   └── thu_mua_success_screen.dart
    └── widgets/
        └── thu_mua_tab.dart
```

## 4. Quy tắc phụ thuộc

```text
presentation -> repository interface -> API repository -> ApiClient
       |                 |                    |
       v                 v                    v
     model             model          ApiConfig + JsonReader
```

- `presentation` được phép dùng model và repository interface.
- API repository được phép dùng `ApiClient`, `JsonReader` và `AuthSessionStore`.
- Model không được import widget, route hoặc API client.
- Feature không nên truy cập widget nội bộ của feature khác.
- Code dùng chung từ hai feature trở lên mới chuyển vào `core`.

## 5. Quy ước đặt tên

- File và thư mục: `snake_case`.
- Class, enum và widget: `PascalCase`.
- Biến và phương thức: `camelCase`.
- Interface dữ liệu: `<Feature>Repository`.
- Lớp gọi API: `Api<Feature>Repository`.
- Màn hình: `<Feature>Screen`.
- Tab nằm trong Home: `<Feature>Tab`.
- Text giao diện dùng tiếng Việt; tên file và tên class dùng tiếng Anh hoặc tên nghiệp vụ đã thống nhất.

## 6. Vị trí thêm code mới

| Nhu cầu | Vị trí |
| --- | --- |
| Thêm endpoint cho một feature | `features/<feature>/data/` |
| Thêm model phản ánh dữ liệu mobile | `features/<feature>/models/` |
| Thêm màn hình | `features/<feature>/presentation/screens/` |
| Thêm widget riêng | `features/<feature>/presentation/widgets/` |
| Thêm route | `core/routes/app_routes.dart` |
| Thêm cấu hình môi trường | `core/config/` |
| Thêm widget dùng chung | `core/widgets/` |

Không thêm lại các thư mục cũ `inbound`, `outbound`, `inventory`. Code hiện tại đã thống nhất dùng `thu_mua`, `giao_hang`, `kho`.

Xem tiếp [APP_CODE_FLOW.md](APP_CODE_FLOW.md) để theo dõi luồng chạy và [API_INTEGRATION_FLOW.md](API_INTEGRATION_FLOW.md) để xem luồng kết nối backend.
