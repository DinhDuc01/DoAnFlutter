import 'package:mobile_scanner/mobile_scanner.dart';

/// Phân loại kết quả quét được.
enum ScanResultKind {
  /// QR sản phẩm hợp lệ trong hệ thống
  productQr,

  /// QR khác (không phải sản phẩm hoặc ngoài hệ thống)
  otherQr,

  /// Barcode vạch tuyến tính
  barcode,

  /// Mã không xác định
  unknown,
}

/// Đại diện cho thông tin kết quả sau khi quét mã QR/Barcode (Scan Result Info).
class ScanResultInfo {
  /// Khởi tạo [ScanResultInfo] với các thông số bắt buộc.
  const ScanResultInfo({
    required this.rawValue,
    required this.format,
    required this.kind,
    this.productCode,
  });

  /// Giá trị văn bản thô đọc được từ mã.
  final String rawValue;

  /// Định dạng của mã (QR Code, Barcode 1D, v.v.).
  final BarcodeFormat format;

  /// Phân loại loại kết quả quét được.
  final ScanResultKind kind;

  /// Mã sản phẩm được bóc tách từ thông tin thô (nếu có).
  final String? productCode;

  /// Kiểm tra xem có phải định dạng QR Code hay không.
  bool get isQr => format == BarcodeFormat.qrCode;

  /// Kiểm tra xem có phải định dạng Barcode vạch hay không.
  bool get isBarcode => !isQr && format != BarcodeFormat.unknown;

  /// Trả về tiêu đề tiếng Việt đại diện cho từng loại kết quả quét.
  String get title {
    switch (kind) {
      case ScanResultKind.productQr:
        return 'QR sản phẩm';
      case ScanResultKind.otherQr:
        return 'QR khác';
      case ScanResultKind.barcode:
        return 'Barcode';
      case ScanResultKind.unknown:
        return 'Mã chưa xác định';
    }
  }

  /// Tạo đối tượng [ScanResultInfo] từ đối tượng Barcode quét được của thư viện mobile_scanner.
  static ScanResultInfo fromBarcode(Barcode barcode) {
    final rawValue = barcode.rawValue?.trim() ?? '';
    final format = barcode.format;
    final productCode = _extractProductCode(rawValue);

    return ScanResultInfo(
      rawValue: rawValue,
      format: format,
      productCode: productCode,
      kind: _detectKind(format, productCode),
    );
  }

  /// Phân loại kết quả dựa trên định dạng mã và mã sản phẩm bóc tách được.
  static ScanResultKind _detectKind(BarcodeFormat format, String? productCode) {
    if (format == BarcodeFormat.qrCode) {
      return productCode == null
          ? ScanResultKind.otherQr
          : ScanResultKind.productQr;
    }
    if (format == BarcodeFormat.unknown) return ScanResultKind.unknown;
    return ScanResultKind.barcode;
  }

  /// Bóc tách mã sản phẩm từ chuỗi thô của mã (hỗ trợ dạng SKU-xxx, SP-xxx hoặc trích xuất từ tham số URL).
  static String? _extractProductCode(String value) {
    if (value.isEmpty) return null;

    final upper = value.toUpperCase();
    if (upper.startsWith('SKU-') ||
        upper.startsWith('SP-') ||
        upper.startsWith('PRODUCT-')) {
      return value;
    }

    final uri = Uri.tryParse(value);
    if (uri != null) {
      final fromSku = uri.queryParameters['sku'];
      if (fromSku != null && fromSku.trim().isNotEmpty) return fromSku.trim();

      final fromProduct = uri.queryParameters['product'];
      if (fromProduct != null && fromProduct.trim().isNotEmpty) {
        return fromProduct.trim();
      }

      final segments = uri.pathSegments;
      final productIndex =
          segments.indexWhere((segment) => segment.toLowerCase() == 'product');
      if (productIndex >= 0 && productIndex + 1 < segments.length) {
        return segments[productIndex + 1];
      }
    }

    return null;
  }
}
