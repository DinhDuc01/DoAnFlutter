import 'package:mobile_scanner/mobile_scanner.dart';

enum ScanResultKind {
  productQr,
  otherQr,
  barcode,
  unknown,
}

class ScanResultInfo {
  const ScanResultInfo({
    required this.rawValue,
    required this.format,
    required this.kind,
    this.productCode,
  });

  final String rawValue;
  final BarcodeFormat format;
  final ScanResultKind kind;
  final String? productCode;

  bool get isQr => format == BarcodeFormat.qrCode;
  bool get isBarcode => !isQr && format != BarcodeFormat.unknown;

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

  static ScanResultKind _detectKind(BarcodeFormat format, String? productCode) {
    if (format == BarcodeFormat.qrCode) {
      return productCode == null ? ScanResultKind.otherQr : ScanResultKind.productQr;
    }
    if (format == BarcodeFormat.unknown) return ScanResultKind.unknown;
    return ScanResultKind.barcode;
  }

  static String? _extractProductCode(String value) {
    if (value.isEmpty) return null;

    final upper = value.toUpperCase();
    if (upper.startsWith('SKU-') || upper.startsWith('SP-') || upper.startsWith('PRODUCT-')) {
      return value;
    }

    final uri = Uri.tryParse(value);
    if (uri != null) {
      final fromSku = uri.queryParameters['sku'];
      if (fromSku != null && fromSku.trim().isNotEmpty) return fromSku.trim();

      final fromProduct = uri.queryParameters['product'];
      if (fromProduct != null && fromProduct.trim().isNotEmpty) return fromProduct.trim();

      final segments = uri.pathSegments;
      final productIndex = segments.indexWhere((segment) => segment.toLowerCase() == 'product');
      if (productIndex >= 0 && productIndex + 1 < segments.length) {
        return segments[productIndex + 1];
      }
    }

    return null;
  }
}
