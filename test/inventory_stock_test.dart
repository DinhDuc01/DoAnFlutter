import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/kho/data/inventory_stock_repository.dart';
import 'package:stocklite/features/kho/models/inventory_stock.dart';

void main() {
  group('InventoryStockLine', () {
    test('giữ nguyên phần lẻ kg thay vì làm tròn', () {
      final line = InventoryStockLine.fromJson(const {
        'id': 7,
        'warehouseId': 1,
        'productVariantId': 3,
        'quantityOnHand': 1234.567,
        'quantityReserved': 34.5,
        'quantityAvailable': 1200.067,
      });

      // Lỗi cũ: model dùng int + .round() nên 1234.567 kg thành 1235 kg.
      expect(line.quantityOnHand, 1234.567);
      expect(line.quantityReserved, 34.5);
      expect(line.quantityAvailable, 1200.067);
    });

    test('ưu tiên mã lô làm tiêu đề, không có lô thì dùng SKU', () {
      final withLot = InventoryStockLine.fromJson(const {
        'id': 1,
        'warehouseId': 1,
        'productVariantId': 1,
        'quantityOnHand': 10,
        'quantityReserved': 0,
        'quantityAvailable': 10,
        'lotCode': 'LOT-001',
        'sku': 'GAO-5451',
      });
      final withoutLot = InventoryStockLine.fromJson(const {
        'id': 2,
        'warehouseId': 1,
        'productVariantId': 1,
        'quantityOnHand': 10,
        'quantityReserved': 0,
        'quantityAvailable': 10,
        'sku': 'GAO-5451',
      });

      expect(withLot.title, 'LOT-001');
      expect(withoutLot.title, 'GAO-5451');
    });

    test('đánh dấu cần chú ý khi cách ly, tồn thấp hoặc không bán được', () {
      InventoryStockLine build(Map<String, dynamic> extra) =>
          InventoryStockLine.fromJson({
            'id': 1,
            'warehouseId': 1,
            'productVariantId': 1,
            'quantityOnHand': 10,
            'quantityReserved': 0,
            'quantityAvailable': 10,
            ...extra,
          });

      expect(build(const {}).needsAttention, isFalse);
      expect(build(const {'quantityQuarantine': 5}).needsAttention, isTrue);
      expect(build(const {'isLowStock': true}).needsAttention, isTrue);
      expect(build(const {'lotIsSellable': false}).needsAttention, isTrue);
    });

    test('đọc được quarantinedKg khi backend chưa trả quantityQuarantine', () {
      final line = InventoryStockLine.fromJson(const {
        'id': 1,
        'warehouseId': 1,
        'productVariantId': 1,
        'quantityOnHand': 10,
        'quantityReserved': 0,
        'quantityAvailable': 10,
        'quarantinedKg': 4.25,
      });

      expect(line.quantityQuarantine, 4.25);
      expect(line.isQuarantined, isTrue);
    });
  });

  group('InventoryStockSummary', () {
    test('map đủ 5 chỉ số KPI và các bộ đếm cảnh báo', () {
      final summary = InventoryStockSummary.fromJson(const {
        'totalOnHand': 1000.5,
        'totalAvailable': 800.25,
        'totalReserved': 150.25,
        'totalProcessing': 30,
        'totalQuarantine': 20,
        'lineCount': 12,
        'quarantineLotCount': 2,
        'lowStockCount': 3,
      });

      expect(summary.totalOnHand, 1000.5);
      expect(summary.totalAvailable, 800.25);
      expect(summary.totalReserved, 150.25);
      expect(summary.totalProcessing, 30);
      expect(summary.totalQuarantine, 20);
      expect(summary.lineCount, 12);
      expect(summary.quarantineLotCount, 2);
      expect(summary.lowStockCount, 3);
    });

    test('mặc định về 0 khi backend không trả summary', () {
      const summary = InventoryStockSummary();
      expect(summary.totalOnHand, 0);
      expect(summary.lineCount, 0);
    });
  });

  group('InventoryStockFilter', () {
    test('clearWarehouse xoá bộ lọc kho thay vì giữ giá trị cũ', () {
      const filter = InventoryStockFilter(warehouseId: 4);
      expect(filter.copyWith(clearWarehouse: true).warehouseId, isNull);
      expect(filter.copyWith(warehouseId: 9).warehouseId, 9);
    });

    test('isEmpty phản ánh đúng trạng thái không lọc gì', () {
      expect(const InventoryStockFilter().isEmpty, isTrue);
      expect(const InventoryStockFilter(keyword: '   ').isEmpty, isTrue);
      expect(const InventoryStockFilter(keyword: 'LOT').isEmpty, isFalse);
      expect(const InventoryStockFilter(lowStockOnly: true).isEmpty, isFalse);
    });
  });
}
