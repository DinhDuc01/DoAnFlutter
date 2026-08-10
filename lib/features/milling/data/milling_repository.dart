import '../models/milling_order.dart';

/// Data boundary for the mobile milling completion workflow.
abstract class MillingRepository {
  Future<List<MillingProductOption>> getOutputProducts() async => const [];

  Future<MillingOrder> getActiveOrder();

  Future<void> saveRiceBags(MillingOrder order);

  Future<void> saveBranBags(MillingOrder order);

  Future<void> completeOrder(MillingOrder order);
}

/// Offline implementation used to exercise all screens before API wiring.
class MockMillingRepository implements MillingRepository {
  @override
  Future<List<MillingProductOption>> getOutputProducts() async => const [
        MillingProductOption(
          id: 101,
          sku: 'RICE-001',
          name: 'Gạo thành phẩm',
          outputType: 'RICE',
        ),
        MillingProductOption(
          id: 102,
          sku: 'BRAN-001',
          name: 'Cám',
          outputType: 'BRAN',
        ),
        MillingProductOption(
          id: 103,
          sku: 'BROKEN-001',
          name: 'Tấm',
          outputType: 'BROKEN',
        ),
      ];

  @override
  Future<MillingOrder> getActiveOrder() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    return MillingOrder(
      id: 21,
      millingCode: 'MO-2026-021',
      inputLotCode: 'IR50404',
      inputWeightKg: 5000,
      warehouseZone: 'Khu A',
      locationCode: 'Cột A03-A04',
      scaleCode: 'SCALE-03',
      riceBags: List<MillingBag>.generate(
        10,
        (index) => MillingBag(index: index + 1, weightKg: 25),
      ),
      branBags: const [
        MillingBag(index: 1, weightKg: 20),
        MillingBag(index: 2, weightKg: 20),
        MillingBag(index: 3, weightKg: 19.5),
        MillingBag(index: 4, weightKg: 20),
        MillingBag(index: 5, weightKg: 20),
      ],
      riceProductVariantId: 101,
      branProductVariantId: 102,
      brokenProductVariantId: 103,
    );
  }

  @override
  Future<void> saveRiceBags(MillingOrder order) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> saveBranBags(MillingOrder order) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> completeOrder(MillingOrder order) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }
}
