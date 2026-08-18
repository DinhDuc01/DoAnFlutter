import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/products/data/product_variant_api.dart';

void main() {
  test('inventory list keeps the latest stocktake date', () {
    final stock = ProductStock.fromInventoryList([
      {
        'id': 1,
        'warehouseName': 'Kho A',
        'quantityOnHand': 2,
        'quantityReserved': 0,
        'lastStockTakeDate': '2026-07-10T08:00:00Z',
      },
      {
        'id': 2,
        'warehouseName': 'Kho B',
        'quantityOnHand': 3,
        'quantityReserved': 1,
        'lastStockTakeDate': '2026-07-15T08:00:00Z',
      },
    ]);

    expect(stock.quantityOnHand, 5);
    expect(stock.quantityAvailable, 4);
    expect(stock.warehouses, hasLength(2));
    expect(stock.lastStockTakeDate?.day, 15);
  });
}
