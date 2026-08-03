import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/kho/data/api_kho_check_repository.dart';
import 'package:stocklite/features/products/data/product_variant_api.dart';

void main() {
  test('warehouse draft only contains products with on-hand stock', () async {
    final repository = ApiKhoCheckRepository(
      productVariantApi: _FakeProductVariantApi(),
    );

    final check = await repository.getDraftCheck();

    expect(check.items, hasLength(1));
    expect(check.items.single.productVariantId, 11);
    expect(check.items.single.productName, 'Gạo ST25 túi 5kg');
    expect(check.items.single.systemQuantity, 8);
    expect(check.warehouseName, 'Kho Cần Thơ');
    expect(check.checkedAt, isA<DateTime>());
  });

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

class _FakeProductVariantApi extends ProductVariantApi {
  @override
  Future<List<ProductVariantStock>> activeVariantsWithStock() async {
    return [
      ProductVariantStock(
        id: 11,
        name: 'Gạo ST25 túi 5kg',
        sku: 'ST25-5KG',
        weightKg: 5,
        quantityOnHand: 8,
        quantityReserved: 1,
        quantityAvailable: 7,
        lastStockTakeDate: DateTime(2026, 7, 15),
        warehouses: const [
          WarehouseInventory(
            inventoryId: 1,
            warehouseId: 101,
            warehouseName: 'Kho Cần Thơ',
            quantityOnHand: 8,
            quantityReserved: 1,
            quantityAvailable: 7,
          ),
        ],
      ),
      const ProductVariantStock(
        id: 12,
        name: 'Gạo Jasmine',
        sku: 'JASMINE',
        weightKg: 10,
        quantityOnHand: 0,
        quantityReserved: 0,
        quantityAvailable: 0,
      ),
    ];
  }
}
