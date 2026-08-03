# StockLite

StockLite la ung dung Flutter ho tro quan ly chuoi cung ung lua gao: dang nhap, thu mua, kho, giao hang, xay xat, kiem ke, quet QR, thong bao, lich su, bao cao va tai khoan.

## Cong nghe

- Flutter SDK `>=3.4.0 <4.0.0`
- Dart
- `mobile_scanner` de quet ma QR/barcode
- `flutter_lints` de kiem tra chat luong code

## Cach chay du an

```powershell
flutter pub get
flutter run
```

Kiem tra loi lint va test:

```powershell
flutter analyze
flutter test
```

## Cau truc thu muc

Du an dang duoc to chuc theo huong **feature-first**. Moi tinh nang nam trong mot thu muc rieng, giup de tim code va giam viec tron logic giua cac man hinh.

```text
lib/
├── main.dart
├── app/
│   └── app.dart
├── core/
│   ├── api/
│   ├── config/
│   ├── routes/
│   ├── theme/
│   └── widgets/
└── features/
    ├── account/
    ├── auth/
    ├── history/
    ├── home/
    ├── giao_hang/
    ├── kho/
    ├── notifications/
    ├── products/
    ├── reports/
    ├── scan/
    ├── thu_mua/
    └── milling/
```

## Vai tro tung khu vuc

### `lib/main.dart`

Diem vao cua ung dung. File nay chi nen khoi tao app va goi widget goc.

### `lib/app/`

Chua cau hinh cap ung dung, vi du `MaterialApp`, theme, routes va cac controller dung o muc app.

### `lib/core/`

Chua code dung chung cho nhieu tinh nang:

- `api/`: cau hinh client API, ham doc JSON, xu ly request chung.
- `config/`: hang so cau hinh nhu base URL API.
- `routes/`: khai bao route va dieu huong man hinh.
- `theme/`: mau sac, theme, controller doi theme.
- `widgets/`: widget dung chung, khong phu thuoc rieng vao mot feature.

### `lib/features/`

Chua cac tinh nang doc lap. Moi feature nen giu cau truc thong nhat:

```text
features/<feature_name>/
├── data/
├── models/
└── presentation/
    ├── screens/
    └── widgets/
```

- `data/`: repository interface, API adapter va data source cua feature.
- `models/`: model du lieu cua feature.
- `presentation/screens/`: cac man hinh chinh.
- `presentation/widgets/`: widget nho chi phuc vu feature do.

Vi du:

```text
features/milling/
├── data/
│   └── milling_repository.dart
├── models/
│   └── milling_order.dart
└── presentation/
    ├── screens/
    │   ├── milling_preparation_screen.dart
    │   ├── rice_weighing_screen.dart
    │   ├── bran_weighing_screen.dart
    │   └── milling_result_confirmation_screen.dart
    └── widgets/milling_widgets.dart
```

## Quy uoc khi them code moi

- Them man hinh moi vao `features/<feature>/presentation/screens/`.
- Them widget rieng cua man hinh vao `features/<feature>/presentation/widgets/`.
- Them model vao `features/<feature>/models/`.
- Them logic goi API va repository vao `features/<feature>/data/`.
- Neu code duoc dung lai o tu 2 feature tro len, dua vao `core/`.
- Ten file Dart dung `snake_case`, vi du `milling_result_confirmation_screen.dart`.
- Ten class/widget dung `PascalCase`, vi du `MillingResultConfirmationScreen`.
- Han che dat logic xu ly du lieu truc tiep trong widget; uu tien dua vao repository/service hoac controller rieng neu logic phuc tap.

## Tai lieu bo sung

Thu muc `docs/` chua cac tai lieu phan tich va test:

- `TEST_PLAN.md`: ke hoach test.
- `INTEGRATION_TEST_GUIDE.md`: huong dan test tich hop.
- `FULL_PROJECT_TEST_SCOPE.md`: pham vi test toan du an.
- `CODE_ORGANIZATION.md`: cau truc va quy tac to chuc source code.
- `APP_CODE_FLOW.md`: luong khoi dong, dang nhap, Home va cac nghiep vu.
- `API_INTEGRATION_FLOW.md`: cau hinh moi truong, token va man hinh ket noi API.
- `API_CONNECTION_STATUS.md`: bang trang thai ket noi endpoint.
- `MILLING_MOBILE_FLOW.md`: ten goi, cau truc code va luong nghiep vu xay xat.

## Ghi chu phat trien

Khi them mot feature moi, tao cau truc nhu sau:

```text
lib/features/new_feature/
├── data/
├── models/
└── presentation/
    ├── screens/
    └── widgets/
```

Sau do khai bao route trong `lib/core/routes/app_routes.dart` neu feature co man hinh rieng can dieu huong.
