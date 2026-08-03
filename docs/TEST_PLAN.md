# StockLite Mobile Test Plan

## 1. Mục tiêu

Tài liệu này mô tả kế hoạch test cho ứng dụng StockLite Mobile ở giai đoạn frontend/mock data.

Mục tiêu chính:

- Kiểm tra các màn hình hiển thị đúng theo thiết kế.
- Kiểm tra luồng điều hướng giữa các màn.
- Kiểm tra các thao tác cơ bản như đăng nhập, thu mua, giao hàng, kiểm kho, xay xát, xem lịch sử, thông báo, tài khoản và quét QR.
- Ghi nhận các điểm hiện đang dùng mock data để test lại sau khi nối API.

## 2. Phạm vi test

Các màn hình cần test:

- Đăng nhập
- Trang chủ
- Nhập kho
- Nhập kho thành công
- Xuất kho
- Xuất kho thành công
- Kiểm kho
- Xay xát: chuẩn bị, cân gạo, cân cám, xác nhận kết quả
- Lịch sử thao tác
- Thông báo
- Tài khoản cá nhân
- Quét mã QR

Ngoài phạm vi hiện tại:

- API thật
- Xác thực token thật
- Camera/QR scanner thật
- Push notification thật
- Phân quyền người dùng thật
- Build release/store deployment

## 3. Môi trường test

Khuyến nghị:

- OS: Windows 10/11
- Flutter: channel stable
- Thiết bị: Android Emulator hoặc điện thoại Android thật
- Màn hình emulator gợi ý: Small Phone / Pixel tương đương

Lệnh chuẩn bị:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

## 4. Tài khoản test

Hiện app dùng mock login.

Thông tin hiển thị mặc định:

```text
Email: nhanvien@stocklite.vn
Password: 123456
```

Ghi chú: ở giai đoạn mock, form đăng nhập chỉ cần email và mật khẩu không rỗng là có thể vào app.

## 5. Test smoke

| ID | Mô tả | Bước test | Kết quả mong đợi |
| --- | --- | --- | --- |
| SM-01 | Mở app | Chạy `flutter run` | App mở màn Đăng nhập |
| SM-02 | Login mock | Bấm Đăng nhập | Chuyển sang Trang chủ |
| SM-03 | Điều hướng nhanh | Bấm từng ô chức năng ở Trang chủ | Mở đúng màn tương ứng |
| SM-04 | Bottom navigation | Bấm Trang chủ / Thông báo / Tài khoản | Chuyển đúng tab |
| SM-05 | Không crash | Đi qua tất cả màn chính | App không crash, không màn trắng |

## 6. Test màn Đăng nhập

| ID | Mô tả | Bước test | Kết quả mong đợi |
| --- | --- | --- | --- |
| LG-01 | Hiển thị brand | Mở app | Thấy `StockLite` |
| LG-02 | Hiển thị subtitle | Mở app | Thấy `Ứng dụng quản lý kho tinh gọn` |
| LG-03 | Email mặc định | Mở app | Email là `nhanvien@stocklite.vn` |
| LG-04 | Password mặc định | Mở app | Password có sẵn và bị ẩn |
| LG-05 | Đăng nhập thành công | Bấm Đăng nhập | Vào Trang chủ |
| LG-06 | Loading state | Bấm Đăng nhập | Nút đổi sang trạng thái đang đăng nhập trong thời gian ngắn |

## 7. Test màn Trang chủ

| ID | Mô tả | Bước test | Kết quả mong đợi |
| --- | --- | --- | --- |
| HM-01 | Header user | Vào Trang chủ | Thấy lời chào và tên nhân viên |
| HM-02 | Kho hoạt động | Vào Trang chủ | Thấy kho đang hoạt động |
| HM-03 | Thao tác nhanh | Vào Trang chủ | Thấy 6 chức năng hiện trường: Thu mua, Kho, Giao hàng, Xay xát, Kiểm chất, Kiểm kê |
| HM-04 | Mở Nhập kho | Bấm Nhập kho | Vào màn Phiếu nhập kho |
| HM-05 | Mở Xuất kho | Bấm Xuất kho | Vào màn Phiếu xuất kho |
| HM-06 | Mở Kiểm kho | Bấm Kiểm kho | Vào màn Phiếu kiểm kho |
| HM-07 | Mở Quét QR | Bấm Quét QR | Vào màn Quét mã QR |
| HM-08 | Mở Lịch sử | Bấm Lịch sử | Vào màn Lịch sử thao tác |
| HM-09 | Mở Xay xát | Bấm Xay xát | Vào màn Hoàn tất xay & đóng bao, không chuyển sang tab Kho |

## 8. Test màn Nhập kho

| ID | Mô tả | Bước test | Kết quả mong đợi |
| --- | --- | --- | --- |
| IN-01 | Load phiếu nhập | Mở Nhập kho | Thấy sản phẩm, mã phiếu, khối lượng |
| IN-02 | Giảm số lượng | Bấm nút `-` | Số lượng giảm 1, không âm |
| IN-03 | Tăng số lượng | Bấm nút `+` | Số lượng tăng 1 |
| IN-04 | Nhập ghi chú | Gõ ghi chú | Text hiển thị trong ô ghi chú |
| IN-05 | Xác nhận nhập kho | Bấm Xác nhận nhập kho | Chuyển sang màn Nhập kho thành công |
| IN-06 | Success data | Xem màn thành công | Số lượng, sản phẩm, mã phiếu hiển thị đúng theo phiếu |
| IN-07 | Quay về trang chủ | Bấm Quay về trang chủ | Về Trang chủ |

## 9. Test màn Xuất kho

| ID | Mô tả | Bước test | Kết quả mong đợi |
| --- | --- | --- | --- |
| OUT-01 | Load phiếu xuất | Mở Xuất kho | Thấy sản phẩm, mã phiếu, khách hàng |
| OUT-02 | Giảm số lượng | Bấm nút `-` | Số lượng giảm 1, không âm |
| OUT-03 | Tăng số lượng | Bấm nút `+` | Số lượng tăng 1 |
| OUT-04 | Nhập ghi chú | Gõ ghi chú | Text hiển thị trong ô ghi chú |
| OUT-05 | Xác nhận xuất kho | Bấm Xác nhận xuất kho | Chuyển sang màn Xuất kho thành công |
| OUT-06 | Success data | Xem màn thành công | Số lượng, sản phẩm, mã phiếu hiển thị đúng theo phiếu |
| OUT-07 | Quay về trang chủ | Bấm Quay về trang chủ | Về Trang chủ |

## 10. Test màn Kiểm kho

| ID | Mô tả | Bước test | Kết quả mong đợi |
| --- | --- | --- | --- |
| INV-01 | Load phiếu kiểm | Mở Kiểm kho | Thấy mã phiếu, kho, danh sách sản phẩm |
| INV-02 | Hiển thị tồn hệ thống | Xem từng item | Có số lượng hệ thống |
| INV-03 | Nhập số thực tế | Gõ số vào ô Thực tế | Ô nhận số |
| INV-04 | Tính chênh lệch âm | Nhập số nhỏ hơn hệ thống | Badge hiển thị số âm màu đỏ |
| INV-05 | Tính chênh lệch dương | Nhập số lớn hơn hệ thống | Badge hiển thị số dương |
| INV-06 | Không nhập thực tế | Để trống | Chênh lệch hiển thị `—` |
| INV-07 | Nhập ghi chú | Gõ ghi chú | Text hiển thị |
| INV-08 | Xác nhận kiểm kho | Bấm Xác nhận kiểm kho | Hiển thị thông báo xác nhận mock |

## 11. Test luồng Xay xát

| ID | Mô tả | Bước test | Kết quả mong đợi |
| --- | --- | --- | --- |
| MILL-01 | Mở lệnh xay | Bấm Xay xát từ Home | Hiển thị mã lệnh, lô lúa, khối lượng, vị trí và cân |
| MILL-02 | Trạng thái tải | Chọn Đang tải | Hiển thị skeleton, không vỡ bố cục |
| MILL-03 | Trạng thái lỗi | Chọn Lỗi tải | Hiển thị lỗi và nút Thử lại |
| MILL-04 | Cân gạo | Bấm Bắt đầu cân gạo | Hiển thị dữ liệu cân trực tiếp, 10 bao và tổng 250kg |
| MILL-05 | Cân cám | Bấm Tiếp tục cân cám | Hiển thị 5 bao và tổng 99.5kg |
| MILL-06 | Xác nhận | Bấm Xác nhận kết quả xay | Hiển thị tổng gạo, cám, yield và chi tiết từng bao |
| MILL-07 | Hoàn tất | Bấm Hoàn tất mẻ xay | Hiển thị xác nhận thành công và cho phép về Home |

## 12. Test màn Lịch sử thao tác

| ID | Mô tả | Bước test | Kết quả mong đợi |
| --- | --- | --- | --- |
| HIS-01 | Load lịch sử | Mở Lịch sử | Thấy danh sách giao dịch |
| HIS-02 | Count giao dịch | Xem header | Số giao dịch đúng với danh sách |
| HIS-03 | Phân loại màu | Xem item Nhập/Xuất/Kiểm | Màu và icon khác nhau theo loại |
| HIS-04 | Số lượng thay đổi | Xem item | Nhập kho có `+`, xuất/kiểm có `-` nếu âm |
| HIS-05 | Back | Bấm back | Quay lại màn trước |

## 13. Test màn Thông báo

| ID | Mô tả | Bước test | Kết quả mong đợi |
| --- | --- | --- | --- |
| NOTI-01 | Load thông báo | Mở Thông báo | Thấy danh sách thông báo |
| NOTI-02 | Count chưa đọc | Xem header | Hiển thị số thông báo chưa đọc |
| NOTI-03 | Filter Tất cả | Bấm Tất cả | Hiện toàn bộ thông báo |
| NOTI-04 | Filter Chưa đọc | Bấm Chưa đọc | Chỉ hiện thông báo chưa đọc |
| NOTI-05 | Filter Cảnh báo | Bấm Cảnh báo | Chỉ hiện cảnh báo |
| NOTI-06 | Đọc tất cả | Bấm Đọc tất cả | Unread count về 0 |
| NOTI-07 | Đóng thông báo | Bấm icon `x` | Thông báo bị loại khỏi danh sách |
| NOTI-08 | Empty filter | Lọc khi không có data phù hợp | Hiển thị text empty |

## 14. Test màn Tài khoản

| ID | Mô tả | Bước test | Kết quả mong đợi |
| --- | --- | --- | --- |
| ACC-01 | Load profile | Mở Tài khoản | Thấy tên, email, vai trò |
| ACC-02 | Thống kê | Xem card thống kê | Có số nhập/xuất/kiểm |
| ACC-03 | Kho phụ trách | Xem card kho | Hiển thị kho được phân công |
| ACC-04 | Toggle thông báo | Bật/tắt switch | Switch đổi trạng thái |
| ACC-05 | Toggle giao diện tối | Bật/tắt switch | Switch đổi trạng thái |
| ACC-06 | Đăng xuất | Bấm Đăng xuất | Quay về màn Login |

## 15. Test màn Quét QR

| ID | Mô tả | Bước test | Kết quả mong đợi |
| --- | --- | --- | --- |
| QR-01 | Load màn QR | Mở Quét QR | Thấy header đen và vùng quét |
| QR-02 | Nút flash | Bấm icon flash | Không crash |
| QR-03 | Quét ngay | Bấm Quét ngay | Hiện SnackBar mock |
| QR-04 | Đổi camera | Bấm Đổi camera | Không crash |
| QR-05 | Thư viện ảnh | Bấm Thư viện ảnh | Không crash |
| QR-06 | Back | Bấm back | Quay lại màn trước |

## 16. Test điều hướng

| ID | Mô tả | Bước test | Kết quả mong đợi |
| --- | --- | --- | --- |
| NAV-01 | Login to Home | Login | Vào Home |
| NAV-02 | Home to feature | Bấm từng quick action | Mở đúng feature |
| NAV-03 | Feature to Home | Bấm bottom nav Trang chủ | Về Home |
| NAV-04 | Notification tab | Bấm bottom nav Thông báo | Vào Thông báo |
| NAV-05 | Account tab | Bấm bottom nav Tài khoản | Vào Tài khoản |
| NAV-06 | Success back home | Từ success bấm Quay về trang chủ | Về Home và clear stack |

## 17. Test responsive/UI

Kiểm tra trên ít nhất 2 kích thước:

- Small Phone emulator
- Một emulator/thiết bị màn lớn hơn

Checklist:

- Text không bị tràn ra ngoài card.
- Button không bị mất chữ.
- Danh sách scroll được.
- Bottom navigation không che nội dung chính.
- Màn success căn giữa hợp lý.
- Màn QR giữ bố cục ổn trên màn cao/thấp.

## 18. Test regression sau khi nối API

Khi backend/API được nối, cần test lại các điểm có note `API_SWAP` trong code:

- Auth login
- Load profile
- Load home data
- Load phiếu nhập
- Confirm nhập kho
- Load phiếu xuất
- Confirm xuất kho
- Load phiếu kiểm kho
- Confirm kiểm kho
- Load lịch sử
- Load thông báo
- Mark all notifications as read
- Dismiss notification
- Logout

## 19. Tiêu chí pass

Một build được xem là pass frontend smoke nếu:

- `flutter analyze` không lỗi.
- `flutter test` pass.
- App mở được trên emulator.
- Login mock vào được Home.
- Tất cả màn chính mở được.
- Không crash khi bấm các button chính.
- Các luồng nhập/xuất kho sang màn success hoạt động.

## 20. Ghi chú cho tester

- Ứng dụng hiện đang dùng mock data.
- Một số button như `Xem chi tiết`, `Đổi camera`, `Thư viện ảnh` chưa có nghiệp vụ thật.
- Màn Quét QR hiện là UI mock, chưa dùng camera thật.
- Khi phát hiện lỗi UI, ghi rõ thiết bị, kích thước màn hình, bước tái hiện và ảnh chụp màn hình.

## 21. Bộ test tự động hiện tại

Kết quả gần nhất ngày 22/07/2026:

- 21 file test.
- 152 test case đã pass.
- Line coverage: 68.29% (`3133/4588` dòng có thể đo).
- Không có lỗi hoặc warning từ analyzer; còn 26 lint mức `info` trong code giao diện.

Các nhóm đã được tự động hóa:

- Đăng nhập đúng/sai, parse session và lỗi API.
- Model nghiệp vụ, JSON reader, QR/barcode parser và dữ liệu cân.
- Repository API cho tài khoản, sản phẩm, tồn kho, thu mua, giao hàng, kiểm kê, kiểm chất, xay xát, báo cáo, lịch sử và thông báo.
- Trạng thái loading, error, empty, success và retry của các màn bất đồng bộ.
- Luồng nhập kho, giao hàng, kiểm kê nhiều chữ số và điều hướng sang màn thành công/chi tiết.
- Smoke test các màn chính, tài khoản, lịch mua hàng và luồng xay xát.
- Cân sản phẩm trong kho bằng nhập tay hoặc cân IoT Bluetooth ESP32.

Lệnh chạy:

```powershell
flutter test
flutter test --coverage
flutter analyze --no-fatal-infos
```

File coverage được tạo tại `coverage/lcov.info`. Camera thật, kết nối BLE thật, quyền Android và nghiệp vụ với backend đang chạy vẫn cần integration test hoặc manual test trên thiết bị.
