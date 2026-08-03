import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/milling/models/milling_order.dart';

void main() {
  group('MillingOrder', () {
    test('calculates rice, bran and yield totals', () {
      final order = _order(
        inputWeightKg: 200,
        riceBags: const [
          MillingBag(index: 1, weightKg: 50.5),
          MillingBag(index: 2, weightKg: 49.5),
        ],
        branBags: const [
          MillingBag(index: 1, weightKg: 20),
          MillingBag(index: 2, weightKg: 10.5),
        ],
      );

      expect(order.totalRiceKg, 100);
      expect(order.totalBranKg, 30.5);
      expect(order.riceYieldPercent, 50);
    });

    test('returns zero yield when input weight is zero', () {
      final order = _order(
        inputWeightKg: 0,
        riceBags: const [MillingBag(index: 1, weightKg: 25)],
      );

      expect(order.riceYieldPercent, 0);
    });

    test('copyWith replaces only the provided bag list', () {
      const originalRice = [MillingBag(index: 1, weightKg: 40)];
      const originalBran = [MillingBag(index: 1, weightKg: 8)];
      final order = _order(
        riceBags: originalRice,
        branBags: originalBran,
      );
      const newRice = [
        MillingBag(index: 1, weightKg: 41),
        MillingBag(index: 2, weightKg: 39),
      ];

      final copied = order.copyWith(riceBags: newRice);

      expect(copied.riceBags, same(newRice));
      expect(copied.branBags, same(originalBran));
      expect(copied.id, order.id);
      expect(copied.millingCode, order.millingCode);
      expect(copied.inputWeightKg, order.inputWeightKg);
    });

    test('empty bag lists produce zero totals', () {
      final order = _order();

      expect(order.totalRiceKg, 0);
      expect(order.totalBranKg, 0);
    });
  });
}

MillingOrder _order({
  double inputWeightKg = 100,
  List<MillingBag> riceBags = const [],
  List<MillingBag> branBags = const [],
}) {
  return MillingOrder(
    id: 1,
    millingCode: 'MO-001',
    inputLotCode: 'LOT-001',
    inputWeightKg: inputWeightKg,
    warehouseZone: 'Zone A',
    locationCode: 'A-01',
    scaleCode: 'SCALE-01',
    riceBags: riceBags,
    branBags: branBags,
  );
}
