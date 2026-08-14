/// Hàm định dạng dùng chung cho các màn nghiệp vụ (tiền, khối lượng, ngày).
///
/// App không phụ thuộc gói `intl` nên các hàm dưới đây tự chèn dấu phân cách
/// nghìn theo kiểu Việt Nam (dấu chấm) giống bản web.
library;

import 'dart:math' as math;

/// Làm tròn LÊN khối lượng về [digits] chữ số thập phân (mặc định 0,1 kg).
///
/// Dùng cho MỌI số kg đi vào chứng từ — số đọc từ cân điện tử lẫn số thủ kho
/// gõ tay — để hai bên (mua lúa, đóng gói xuất kho) không lệch nhau và tổng
/// tiền không phụ thuộc vào chữ số thứ ba của cân.
///
/// Luôn làm tròn lên nên phần chênh nghiêng về phía người bán/khách, không bao
/// giờ ghi thiếu so với cân: `12,31 → 12,4`; `12,30 → 12,3`.
///
/// Nhân/chia số thực gây sai số (`12.3 * 10 = 122.99999999999999`, `ceil` ra
/// 12,4 dù đã tròn), nên phải cắt nhiễu ở chữ số thứ 6 trước khi `ceil`.
/// Chỉ dùng cho khối lượng không âm.
double ceilKg(num? value, {int digits = 1}) {
  final raw = (value ?? 0).toDouble();
  if (!raw.isFinite) return 0;
  final factor = math.pow(10, digits).toDouble();
  final scaled = (raw * factor * 1e6).round() / 1e6;
  return scaled.ceil() / factor;
}

/// `1234567` → `1.234.567 ₫`
String formatMoney(num? value) {
  final rounded = (value ?? 0).round();
  final sign = rounded < 0 ? '-' : '';
  return '$sign${_groupDigits(rounded.abs().toString())} ₫';
}

/// `1234.5` → `1.234,5 kg`
String formatKg(num? value, {int digits = 2}) =>
    '${formatNumber(value, digits: digits)} kg';

/// Số thực với tối đa [digits] chữ số thập phân, bỏ số 0 thừa ở cuối.
String formatNumber(num? value, {int digits = 2}) {
  final raw = (value ?? 0).toDouble();
  final negative = raw < 0;
  final text = raw.abs().toStringAsFixed(digits);
  var integerPart = text;
  var fractionPart = '';
  final dotIndex = text.indexOf('.');
  if (dotIndex >= 0) {
    integerPart = text.substring(0, dotIndex);
    fractionPart = text.substring(dotIndex + 1).replaceAll(RegExp(r'0+$'), '');
  }
  final grouped = _groupDigits(integerPart);
  final suffix = fractionPart.isEmpty ? '' : ',$fractionPart';
  return '${negative ? '-' : ''}$grouped$suffix';
}

/// `dd/MM/yyyy` (thêm giờ khi [withTime]). Trả `—` nếu null.
String formatDate(DateTime? value, {bool withTime = false}) {
  if (value == null) return '—';
  final local = value.toLocal();
  final date =
      '${_pad(local.day)}/${_pad(local.month)}/${local.year.toString().padLeft(4, '0')}';
  if (!withTime) return date;
  return '$date ${_pad(local.hour)}:${_pad(local.minute)}';
}

/// `yyyy-MM-dd` — dùng khi gửi ngày lên API.
String formatIsoDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-${_pad(local.month)}-${_pad(local.day)}';
}

/// Số thuần cho ô nhập (không có dấu phân cách nghìn): `1000`, `12.5`.
///
/// Dùng khi đổ giá trị sẵn vào TextField để [parseDecimal] đọc lại không bị
/// nhầm dấu chấm phân cách nghìn với dấu thập phân.
String formatQuantityInput(num? value, {int digits = 3}) {
  final raw = (value ?? 0).toDouble();
  final text = raw.toStringAsFixed(digits);
  if (!text.contains('.')) return text;
  final trimmed = text.replaceAll(RegExp(r'0+$'), '');
  return trimmed.endsWith('.')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

/// Ép chuỗi người dùng gõ về số thực, chấp nhận cả `1234.5`, `1234,5` và
/// `1.234,5`.
///
/// Quy tắc: nếu có dấu phẩy thì phẩy là dấu thập phân và chấm là phân cách
/// nghìn; nếu chỉ có chấm thì chấm là dấu thập phân, trừ khi xuất hiện nhiều
/// hơn một lần (khi đó là phân cách nghìn).
double? parseDecimal(String? raw) {
  var text = (raw ?? '').trim().replaceAll(' ', '');
  if (text.isEmpty) return null;

  if (text.contains(',')) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  } else if ('.'.allMatches(text).length > 1) {
    text = text.replaceAll('.', '');
  }

  final value = double.tryParse(text);
  return value != null && value.isFinite ? value : null;
}

/// Ép chuỗi tiền (đã format) về số nguyên VNĐ.
int parseMoney(String? raw) {
  final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty ? 0 : int.tryParse(digits) ?? 0;
}

String _groupDigits(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String _pad(int value) => value.toString().padLeft(2, '0');
