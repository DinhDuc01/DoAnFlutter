import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/milling/models/milling_output_form.dart';

LegacyMillingOutputInput legacy(
  MillingOutputType type,
  List<double> weights, {
  int? productId,
  int? locationId,
}) => LegacyMillingOutputInput(
      type: type,
      productVariantId: productId,
      locationId: locationId,
      bagWeightsKg: weights,
    );

void main() {
  test('Rice to Bran preserves RICE output', () {
    final rice = adaptLegacyMillingOutputs(
      [legacy(MillingOutputType.rice, [25, 25, 25, 25])],
    );
    expect(rice, hasLength(1));
    expect(rice.single.type, MillingOutputType.rice);
    expect(rice.single.outputWeightKg, 100);
    expect(rice.single.bagCount, 4);
    expect(rice.single.isByproduct, isFalse);
    expect(rice.where((item) => item.type == MillingOutputType.bran), isEmpty);
  });

  test('Bran to Broken upserts BRAN without losing RICE', () {
    final rice = adaptLegacyMillingOutputs(
      [legacy(MillingOutputType.rice, [25, 25, 25, 25])],
    );
    final withBran = upsertMillingOutput(
      rice,
      adaptLegacyMillingOutputs([legacy(MillingOutputType.bran, [20])]).single,
    );
    expect(withBran.map((item) => item.type), [MillingOutputType.rice, MillingOutputType.bran]);
    expect(withBran.first.outputWeightKg, 100);
    expect(withBran.last.outputWeightKg, 20);
    expect(withBran.last.isByproduct, isTrue);
  });

  test('Skipping Bran does not create an empty output', () {
    final rice = adaptLegacyMillingOutputs(
      [legacy(MillingOutputType.rice, [25, 25, 25, 25])],
    );
    expect(rice, hasLength(1));
    expect(rice.where((item) => item.type == MillingOutputType.bran), isEmpty);
  });

  test('Broken to Result preserves Rice and Bran and excludes Husk', () {
    var outputs = adaptLegacyMillingOutputs([
      legacy(MillingOutputType.rice, [25, 25, 25, 25]),
      legacy(MillingOutputType.bran, [20]),
    ]);
    outputs = upsertMillingOutput(
      outputs,
      adaptLegacyMillingOutputs([legacy(MillingOutputType.broken, [10])]).single,
    );
    expect(outputs.map((item) => item.type), [
      MillingOutputType.rice,
      MillingOutputType.broken,
      MillingOutputType.bran,
    ]);
    expect(outputs.map((item) => item.outputWeightKg), [100, 10, 20]);
    expect(outputs.where((item) => item.type == MillingOutputType.husk), isEmpty);
  });

  test('Skipping Broken preserves Rice and Bran', () {
    final outputs = adaptLegacyMillingOutputs([
      legacy(MillingOutputType.rice, [25, 25, 25, 25]),
      legacy(MillingOutputType.bran, [20]),
    ]);
    expect(outputs.map((item) => item.type), [MillingOutputType.rice, MillingOutputType.bran]);
  });

  test('upsert replaces one type without mutating input', () {
    final initial = adaptLegacyMillingOutputs([legacy(MillingOutputType.rice, [90])]);
    final updated = upsertMillingOutput(
      initial,
      adaptLegacyMillingOutputs([legacy(MillingOutputType.rice, [25, 25, 25, 25])]).single,
    );
    expect(initial.single.outputWeightKg, 90);
    expect(updated, hasLength(1));
    expect(updated.single.outputWeightKg, 100);
  });

  test('invalid legacy weights are discarded without fake IDs', () {
    final outputs = adaptLegacyMillingOutputs([
      legacy(MillingOutputType.rice, [0, -1, double.nan, double.infinity]),
    ]);
    expect(outputs, isEmpty);
    final missing = adaptLegacyMillingOutputs([legacy(MillingOutputType.bran, [20])]).single;
    expect(missing.productVariantId, isNull);
    expect(missing.locationId, isNull);
  });
}
