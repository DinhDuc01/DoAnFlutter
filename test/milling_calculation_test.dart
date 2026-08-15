import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Milling Bag Calculation Tests', () {
    test('calculates bag count with ceil for exact division: 50kg / 10kg = 5 bags', () {
      const double weightKg = 50.0;
      const double kgPerBag = 10.0;
      final bagCount = (weightKg / kgPerBag).ceil();
      expect(bagCount, equals(5));
    });

    test('calculates bag count with ceil for fractional division: 51kg / 10kg = 6 bags', () {
      const double weightKg = 51.0;
      const double kgPerBag = 10.0;
      final bagCount = (weightKg / kgPerBag).ceil();
      expect(bagCount, equals(6));
    });

    test('calculates bag count for 50kg / 50kg = 1 bag', () {
      const double weightKg = 50.0;
      const double kgPerBag = 50.0;
      final bagCount = (weightKg / kgPerBag).ceil();
      expect(bagCount, equals(1));
    });

    test('calculates bag count for 50.5kg / 50kg = 2 bags', () {
      const double weightKg = 50.5;
      const double kgPerBag = 50.0;
      final bagCount = (weightKg / kgPerBag).ceil();
      expect(bagCount, equals(2));
    });
  });
}
