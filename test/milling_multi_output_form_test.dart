import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/milling/models/milling_output_form.dart';

MillingOutputFormValue output(MillingOutputType type, double kg) =>
    MillingOutputFormValue(type: type, productVariantId: 1, locationId: 2, bagCount: 1, kgPerBag: kg, outputWeightKg: kg);

void main() {
  test('summary calculates all output types safely', () {
    final summary = calculateMillingOutputSummary(
      inputWeightKg: 145,
      expectedYield: 100 / 145,
      outputs: [output(MillingOutputType.rice, 100), output(MillingOutputType.broken, 10), output(MillingOutputType.bran, 20), output(MillingOutputType.husk, 5)],
    );
    expect(summary.riceKg, 100);
    expect(summary.byproductKg, 35);
    expect(summary.totalOutputKg, 135);
    expect(summary.lossKg, 10);
    expect(summary.actualYield, closeTo(100 / 145, 0.00001));
  });

  test('invalid values do not produce non-finite summary', () {
    final summary = calculateMillingOutputSummary(inputWeightKg: double.nan, expectedYield: double.infinity, outputs: [const MillingOutputFormValue(type: MillingOutputType.rice, outputWeightKg: double.infinity)]);
    expect(summary.totalOutputKg.isFinite, isTrue);
    expect(summary.actualYield.isFinite, isTrue);
  });

  test('validation reports missing fields and output overflow', () {
    final errors = validateMillingOutputs(inputWeightKg: 10, expectedYield: .7, note: null, outputs: [output(MillingOutputType.rice, 20)]);
    expect(errors.any((error) => error.field == 'totalOutputKg'), isTrue);
  });

  test('payload maps contract fields and excludes kgPerBag', () {
    final payload = buildMillingCompletePayloadPreview(outputs: [output(MillingOutputType.rice, 10), output(MillingOutputType.husk, 2)], note: null);
    final rows = payload['outputs'] as List<dynamic>;
    expect(rows, hasLength(2));
    expect(rows.first, isNot(contains('kgPerBag')));
    expect(rows.last['outputType'], 'HUSK');
    expect(rows.last['isByproduct'], isTrue);
  });
}
