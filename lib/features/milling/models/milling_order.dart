/// A single recorded bag produced by a milling order.
class MillingBag {
  const MillingBag({
    required this.index,
    required this.weightKg,
  });

  final int index;
  final double weightKg;
}

enum MillingScaleMode { iot, manual }

class MillingProductOption {
  const MillingProductOption({
    required this.id,
    required this.name,
    required this.sku,
    required this.outputType,
  });

  final int id;
  final String name;
  final String sku;
  final String outputType;
}

class MillingPaddyLotOption {
  const MillingPaddyLotOption({
    required this.id,
    required this.code,
    required this.warehouseId,
    required this.warehouseName,
    required this.remainingWeightKg,
    this.locationId,
    this.locationCode,
    this.riceVarietyId,
  });

  final int id;
  final String code;
  final int warehouseId;
  final String warehouseName;
  final int? locationId;
  final String? locationCode;
  final int? riceVarietyId;
  final double remainingWeightKg;
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
    this.brokenBags = const [],
    this.scaleMode = MillingScaleMode.iot,
    this.riceProductVariantId = 0,
    this.branProductVariantId = 0,
    this.brokenProductVariantId = 0,
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
  final List<MillingBag> brokenBags;
  final MillingScaleMode scaleMode;
  final int riceProductVariantId;
  final int branProductVariantId;
  final int brokenProductVariantId;

  MillingOrder copyWith({
    List<MillingBag>? riceBags,
    List<MillingBag>? branBags,
    List<MillingBag>? brokenBags,
    MillingScaleMode? scaleMode,
    int? riceProductVariantId,
    int? branProductVariantId,
    int? brokenProductVariantId,
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
      brokenBags: brokenBags ?? this.brokenBags,
      scaleMode: scaleMode ?? this.scaleMode,
      riceProductVariantId: riceProductVariantId ?? this.riceProductVariantId,
      branProductVariantId: branProductVariantId ?? this.branProductVariantId,
      brokenProductVariantId:
          brokenProductVariantId ?? this.brokenProductVariantId,
    );
  }

  /// Total weight of finished rice recorded from all rice bags.
  double get totalRiceKg =>
      riceBags.fold(0, (total, bag) => total + bag.weightKg);

  /// Total weight of bran recorded as a milling by-product.
  double get totalBranKg =>
      branBags.fold(0, (total, bag) => total + bag.weightKg);

  double get totalBrokenKg =>
      brokenBags.fold(0, (total, bag) => total + bag.weightKg);

  /// Finished-rice yield compared with the paddy input weight.
  double get riceYieldPercent =>
      inputWeightKg == 0 ? 0 : totalRiceKg / inputWeightKg * 100;
}
