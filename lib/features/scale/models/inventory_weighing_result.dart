import '../../products/data/product_variant_api.dart';

enum WeighingMethod { manual, iot }

extension WeighingMethodLabel on WeighingMethod {
  String get label => switch (this) {
        WeighingMethod.manual => 'Nhập tay',
        WeighingMethod.iot => 'Cân IoT',
      };
}

class InventoryWeighingResult {
  const InventoryWeighingResult({
    required this.product,
    required this.quantity,
    required this.totalWeightKg,
    required this.method,
    required this.weighedAt,
  });

  final ProductVariantStock product;
  final int quantity;
  final double totalWeightKg;
  final WeighingMethod method;
  final DateTime weighedAt;

  double get averageWeightKg => totalWeightKg / quantity;
  double get expectedWeightKg => product.weightKg * quantity;
}
