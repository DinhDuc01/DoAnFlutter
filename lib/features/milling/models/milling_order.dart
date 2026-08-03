/// A single recorded bag produced by a milling order.
class MillingBag {
  const MillingBag({
    required this.index,
    required this.weightKg,
  });

  final int index;
  final double weightKg;
}

/// Mobile-facing data required to finish and pack a milling order.
class MillingOrder {
  const MillingOrder({
    required this.id,
    required this.millingCode,
    required this.inputLotCode,
    required this.inputWeightKg,
    required this.warehouseZone,
    required this.locationCode,
    required this.scaleCode,
    required this.riceBags,
    required this.branBags,
  });

  final int id;
  final String millingCode;
  final String inputLotCode;
  final double inputWeightKg;
  final String warehouseZone;
  final String locationCode;
  final String scaleCode;
  final List<MillingBag> riceBags;
  final List<MillingBag> branBags;

  MillingOrder copyWith({
    List<MillingBag>? riceBags,
    List<MillingBag>? branBags,
  }) {
    return MillingOrder(
      id: id,
      millingCode: millingCode,
      inputLotCode: inputLotCode,
      inputWeightKg: inputWeightKg,
      warehouseZone: warehouseZone,
      locationCode: locationCode,
      scaleCode: scaleCode,
      riceBags: riceBags ?? this.riceBags,
      branBags: branBags ?? this.branBags,
    );
  }

  /// Total weight of finished rice recorded from all rice bags.
  double get totalRiceKg =>
      riceBags.fold(0, (total, bag) => total + bag.weightKg);

  /// Total weight of bran recorded as a milling by-product.
  double get totalBranKg =>
      branBags.fold(0, (total, bag) => total + bag.weightKg);

  /// Finished-rice yield compared with the paddy input weight.
  double get riceYieldPercent =>
      inputWeightKg == 0 ? 0 : totalRiceKg / inputWeightKg * 100;
}
