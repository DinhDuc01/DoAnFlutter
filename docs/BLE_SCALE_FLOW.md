# Luồng cân Bluetooth StockLite

## Giao thức thiết bị

- Tên quảng bá: `StockLite SCALE-01` (ứng dụng chấp nhận tiền tố `StockLite`).
- Service UUID: `9a8f0001-6f3a-4b6e-9d2a-1c7e3f5a0b10`.
- Weight READ/NOTIFY: `9a8f0002-6f3a-4b6e-9d2a-1c7e3f5a0b10`.
- Command WRITE: `9a8f0003-6f3a-4b6e-9d2a-1c7e3f5a0b10`.
- Lệnh hỗ trợ: `TARE`, `RESET`, `CALIBRATE`.

Payload do ESP32 gửi:

```json
{"w": 2.450, "u": "kg", "s": true}
```

`w` là khối lượng, `u` là đơn vị và `s` cho biết số cân đã ổn định.

## Luồng trong ứng dụng

```text
RiceWeighingScreen / BranWeighingScreen
  -> ScaleScreen
  -> xin quyền Bluetooth
  -> tìm thiết bị theo service UUID hoặc tên StockLite
  -> kết nối và discover characteristics
  -> đăng ký Weight notify
  -> WeightReading.fromBytes()
  -> chỉ bật nút nhận số khi s == true và w > 0
  -> trả WeightReading về màn xay xát
  -> thêm một MillingBag
```

## Nền tảng kiểm thử

- Android thật: hỗ trợ quét và kết nối BLE; đây là môi trường cần dùng để thử với ESP32.
- Android emulator: có thể kiểm tra giao diện nhưng thường không có phần cứng BLE để tìm cân.
- Web: có thể build ứng dụng, nhưng khả năng Web Bluetooth phụ thuộc trình duyệt, HTTPS và quyền của máy; luồng sản xuất ưu tiên Android thật.

Không có API HTTP nào tham gia vào việc đọc cân. Backend chỉ nhận luồng hoàn tất lệnh xay theo `MillingRepository`; dữ liệu cân được giữ local cho tới bước đó.
