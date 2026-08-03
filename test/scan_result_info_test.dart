import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stocklite/features/scan/models/scan_result_info.dart';

void main() {
  test('recognizes direct product QR prefixes', () {
    for (final value in ['SKU-001', 'sp-002', 'PRODUCT-003']) {
      final result = ScanResultInfo.fromBarcode(
        Barcode(rawValue: value, format: BarcodeFormat.qrCode),
      );

      expect(result.kind, ScanResultKind.productQr);
      expect(result.productCode, value);
      expect(result.isQr, isTrue);
      expect(result.isBarcode, isFalse);
      expect(result.title, 'QR sản phẩm');
    }
  });

  test('extracts product code from sku and product URL query parameters', () {
    final sku = ScanResultInfo.fromBarcode(
      const Barcode(
        rawValue: 'https://stocklite.app/item?sku= GAO-01 ',
        format: BarcodeFormat.qrCode,
      ),
    );
    final product = ScanResultInfo.fromBarcode(
      const Barcode(
        rawValue: 'https://stocklite.app/item?product=CAM-02',
        format: BarcodeFormat.qrCode,
      ),
    );

    expect(sku.productCode, 'GAO-01');
    expect(product.productCode, 'CAM-02');
  });

  test('extracts product code from URL path', () {
    final result = ScanResultInfo.fromBarcode(
      const Barcode(
        rawValue: 'https://stocklite.app/product/LOT-99/detail',
        format: BarcodeFormat.qrCode,
      ),
    );

    expect(result.productCode, 'LOT-99');
    expect(result.kind, ScanResultKind.productQr);
  });

  test('classifies non-product QR as other QR', () {
    final result = ScanResultInfo.fromBarcode(
      const Barcode(
        rawValue: 'https://example.com/about',
        format: BarcodeFormat.qrCode,
      ),
    );

    expect(result.kind, ScanResultKind.otherQr);
    expect(result.title, 'QR khác');
  });

  test('classifies a linear code as barcode', () {
    final result = ScanResultInfo.fromBarcode(
      const Barcode(rawValue: '8931234567890', format: BarcodeFormat.ean13),
    );

    expect(result.kind, ScanResultKind.barcode);
    expect(result.isBarcode, isTrue);
    expect(result.title, 'Barcode');
  });

  test('classifies unknown and trims null raw value safely', () {
    final result = ScanResultInfo.fromBarcode(
      const Barcode(format: BarcodeFormat.unknown),
    );

    expect(result.rawValue, '');
    expect(result.kind, ScanResultKind.unknown);
    expect(result.productCode, isNull);
    expect(result.isQr, isFalse);
    expect(result.isBarcode, isFalse);
    expect(result.title, 'Mã chưa xác định');
  });
}
