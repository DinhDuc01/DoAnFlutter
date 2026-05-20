import '../models/inventory_check.dart';

abstract class InventoryCheckRepository {
  Future<InventoryCheck> getDraftCheck();
}

class MockInventoryCheckRepository implements InventoryCheckRepository {
  @override
  Future<InventoryCheck> getDraftCheck() async {
    // API_SWAP: Replace this mock response with GET /inventory-check/draft.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return const InventoryCheck(
      checkCode: 'KK-2025-003',
      warehouseName: 'Kho A',
      noteHint: 'Nhập ghi chú kiểm kho...',
      items: [
        InventoryCheckItem(
          productName: 'Bóng đèn LED 9W',
          sku: 'SKU-0001',
          systemQuantity: 20,
          actualQuantity: 1,
        ),
        InventoryCheckItem(
          productName: 'Cáp sạc Type-C 1m',
          sku: 'SKU-0002',
          systemQuantity: 245,
        ),
        InventoryCheckItem(
          productName: 'Áo thun nam size L',
          sku: 'SKU-0003',
          systemQuantity: 30,
        ),
      ],
    );
  }
}
