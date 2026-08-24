enum MillingOutputType { rice, broken, bran, husk }

extension MillingOutputTypeX on MillingOutputType {
  String get code => switch (this) {
        MillingOutputType.rice => 'RICE',
        MillingOutputType.broken => 'BROKEN',
        MillingOutputType.bran => 'BRAN',
        MillingOutputType.husk => 'HUSK',
      };

  bool get isByproduct => this != MillingOutputType.rice;
}

class MillingOutputFormValue {
  const MillingOutputFormValue({
    required this.type,
    this.productVariantId,
    this.productName,
    this.locationId,
    this.locationName,
    this.bagCount,
    this.kgPerBag,
    this.outputWeightKg,
    this.unitCost,
  });

  final MillingOutputType type;
  final int? productVariantId;
  final String? productName;
  final int? locationId;
  final String? locationName;
  final int? bagCount;
  final double? kgPerBag;
  final double? outputWeightKg;
  final double? unitCost;

  String get outputTypeCode => type.code;
  bool get isByproduct => type.isByproduct;
  double get packedWeightKg => (bagCount ?? 0) * (kgPerBag ?? 0);

  MillingOutputFormValue copyWith({
    int? productVariantId,
    String? productName,
    int? locationId,
    String? locationName,
    int? bagCount,
    double? kgPerBag,
    double? outputWeightKg,
    double? unitCost,
  }) => MillingOutputFormValue(
        type: type,
        productVariantId: productVariantId ?? this.productVariantId,
        productName: productName ?? this.productName,
        locationId: locationId ?? this.locationId,
        locationName: locationName ?? this.locationName,
        bagCount: bagCount ?? this.bagCount,
        kgPerBag: kgPerBag ?? this.kgPerBag,
        outputWeightKg: outputWeightKg ?? this.outputWeightKg,
        unitCost: unitCost ?? this.unitCost,
      );
}

class LegacyMillingOutputInput {
  const LegacyMillingOutputInput({
    required this.type,
    this.productVariantId,
    this.productName,
    this.locationId,
    this.locationName,
    this.bagWeightsKg = const [],
    this.bagCount,
    this.totalWeightKg,
    this.kgPerBag,
  });

  final MillingOutputType type;
  final int? productVariantId;
  final String? productName;
  final int? locationId;
  final String? locationName;
  final List<double> bagWeightsKg;
  final int? bagCount;
  final double? totalWeightKg;
  final double? kgPerBag;
}

List<MillingOutputFormValue> adaptLegacyMillingOutputs(
  List<LegacyMillingOutputInput> legacyOutputs,
) => [
      for (final input in legacyOutputs)
        if (_legacyWeight(input) > 0)
          MillingOutputFormValue(
            type: input.type,
            productVariantId: input.productVariantId,
            productName: input.productName,
            locationId: input.locationId,
            locationName: input.locationName,
            bagCount: _legacyBagCount(input),
            kgPerBag: input.kgPerBag,
            outputWeightKg: _legacyWeight(input),
          ),
    ];

List<MillingOutputFormValue> upsertMillingOutput(
  List<MillingOutputFormValue> current,
  MillingOutputFormValue output,
) {
  final result = [
    for (final item in current)
      if (item.type != output.type) item,
  ];
  result.add(output);
  const order = [MillingOutputType.rice, MillingOutputType.broken, MillingOutputType.bran, MillingOutputType.husk];
  result.sort((a, b) => order.indexOf(a.type).compareTo(order.indexOf(b.type)));
  return List.unmodifiable(result);
}

double _legacyWeight(LegacyMillingOutputInput input) {
  final valid = input.bagWeightsKg.where((weight) => weight.isFinite && weight > 0);
  final sum = valid.fold<double>(0, (total, weight) => total + weight);
  if (sum > 0) return sum;
  final total = input.totalWeightKg;
  return total != null && total.isFinite && total > 0 ? total : 0;
}

int? _legacyBagCount(LegacyMillingOutputInput input) {
  final validCount = input.bagWeightsKg.where((weight) => weight.isFinite && weight > 0).length;
  if (validCount > 0) return validCount;
  return input.bagCount != null && input.bagCount! > 0 ? input.bagCount : null;
}

class MillingOutputSummary {
  const MillingOutputSummary({
    required this.inputWeightKg,
    required this.riceKg,
    required this.brokenKg,
    required this.branKg,
    required this.huskKg,
    required this.byproductKg,
    required this.totalOutputKg,
    required this.lossKg,
    required this.actualYield,
    required this.yieldDifference,
    required this.balanceDifference,
  });

  final double inputWeightKg;
  final double riceKg;
  final double brokenKg;
  final double branKg;
  final double huskKg;
  final double byproductKg;
  final double totalOutputKg;
  final double lossKg;
  final double actualYield;
  final double yieldDifference;
  final double balanceDifference;

  bool get outputExceedsInput => totalOutputKg > inputWeightKg;
}

MillingOutputSummary calculateMillingOutputSummary({
  required double inputWeightKg,
  required double expectedYield,
  required List<MillingOutputFormValue> outputs,
}) {
  double total(MillingOutputType type) => outputs
      .where((output) => output.type == type)
      .fold(0, (sum, output) => sum + _safe(output.outputWeightKg));
  final input = _safe(inputWeightKg);
  final rice = total(MillingOutputType.rice);
  final broken = total(MillingOutputType.broken);
  final bran = total(MillingOutputType.bran);
  final husk = total(MillingOutputType.husk);
  final byproduct = broken + bran + husk;
  final totalOutput = rice + byproduct;
  final double actualYield = input > 0 ? rice / input : 0.0;
  final expected = _safe(expectedYield);
  return MillingOutputSummary(
    inputWeightKg: input,
    riceKg: rice,
    brokenKg: broken,
    branKg: bran,
    huskKg: husk,
    byproductKg: byproduct,
    totalOutputKg: totalOutput,
    lossKg: input - totalOutput,
    actualYield: _safe(actualYield),
    yieldDifference: _safe(actualYield - expected),
    balanceDifference: _safe(input - totalOutput),
  );
}

class MillingOutputValidationError {
  const MillingOutputValidationError({
    required this.outputType,
    required this.field,
    required this.message,
  });

  final MillingOutputType? outputType;
  final String field;
  final String message;
}

List<MillingOutputValidationError> validateMillingOutputs({
  required double inputWeightKg,
  required double expectedYield,
  required String? note,
  required List<MillingOutputFormValue> outputs,
}) {
  final errors = <MillingOutputValidationError>[];
  if (!inputWeightKg.isFinite || inputWeightKg <= 0) {
    errors.add(const MillingOutputValidationError(outputType: null, field: 'inputWeightKg', message: 'Khối lượng đầu vào không hợp lệ.'));
  }
  if (outputs.where((output) => output.type == MillingOutputType.rice).length != 1) {
    errors.add(const MillingOutputValidationError(outputType: MillingOutputType.rice, field: 'outputType', message: 'Cần đúng một đầu ra Gạo.'));
  }
  final seen = <MillingOutputType>{};
  for (final output in outputs) {
    if (!seen.add(output.type)) {
      errors.add(MillingOutputValidationError(outputType: output.type, field: 'outputType', message: 'Loại đầu ra bị trùng.'));
    }
    if (output.productVariantId == null || output.productVariantId! <= 0) errors.add(MillingOutputValidationError(outputType: output.type, field: 'productVariantId', message: 'Chưa chọn SKU.'));
    if (output.locationId == null || output.locationId! <= 0) errors.add(MillingOutputValidationError(outputType: output.type, field: 'locationId', message: 'Chưa chọn vị trí.'));
    if (output.bagCount == null || output.bagCount! <= 0) errors.add(MillingOutputValidationError(outputType: output.type, field: 'bagCount', message: 'Số bao phải lớn hơn 0.'));
    if (output.kgPerBag == null || !output.kgPerBag!.isFinite || output.kgPerBag! <= 0) errors.add(MillingOutputValidationError(outputType: output.type, field: 'kgPerBag', message: 'Kg/bao không hợp lệ.'));
    if (output.outputWeightKg == null || !output.outputWeightKg!.isFinite || output.outputWeightKg! <= 0) errors.add(MillingOutputValidationError(outputType: output.type, field: 'outputWeightKg', message: 'Khối lượng thực tế không hợp lệ.'));
  }
  final summary = calculateMillingOutputSummary(inputWeightKg: inputWeightKg, expectedYield: expectedYield, outputs: outputs);
  if (summary.outputExceedsInput) errors.add(const MillingOutputValidationError(outputType: null, field: 'totalOutputKg', message: 'Tổng đầu ra vượt đầu vào.'));
  if ((summary.actualYield - expectedYield).abs() > 0.02 && (note == null || note.trim().isEmpty)) errors.add(const MillingOutputValidationError(outputType: MillingOutputType.rice, field: 'note', message: 'Yield lệch trên 2%; cần ghi chú.'));
  return errors;
}

Map<String, dynamic> buildMillingCompletePayloadPreview({
  required List<MillingOutputFormValue> outputs,
  required String? note,
  String? machineRef,
  int? operatorId,
  double? lossKg,
  double? byproductKg,
  double? millingCost,
  double? incidentalCost,
}) => {
      'outputs': [
        for (final output in outputs)
          if (output.productVariantId != null && output.productVariantId! > 0 && output.locationId != null && output.locationId! > 0 && output.outputWeightKg != null && output.outputWeightKg!.isFinite && output.outputWeightKg! > 0)
            {
              'productVariantId': output.productVariantId,
              'locationId': output.locationId,
              'outputType': output.outputTypeCode,
              'outputWeightKg': output.outputWeightKg,
              'bagCount': output.bagCount,
              'isByproduct': output.isByproduct,
              'unitCost': output.unitCost,
            },
      ],
      if (machineRef != null && machineRef.trim().isNotEmpty)
        'machineRef': machineRef.trim(),
      if (operatorId != null && operatorId > 0) 'operatorId': operatorId,
      if (lossKg != null && lossKg.isFinite && lossKg >= 0) 'lossKg': lossKg,
      if (byproductKg != null && byproductKg.isFinite && byproductKg >= 0)
        'byproductKg': byproductKg,
      if (millingCost != null && millingCost.isFinite && millingCost >= 0)
        'millingCost': millingCost,
      if (incidentalCost != null &&
          incidentalCost.isFinite &&
          incidentalCost >= 0)
        'incidentalCost': incidentalCost,
      'note': note?.trim().isEmpty ?? true ? null : note!.trim(),
    };

double _safe(double? value) => value != null && value.isFinite ? value : 0;
