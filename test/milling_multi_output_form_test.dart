import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/milling/data/milling_repository.dart';
import 'package:stocklite/features/milling/models/milling_location.dart';
import 'package:stocklite/features/milling/models/milling_order.dart';
import 'package:stocklite/features/milling/models/milling_output_form.dart';
import 'package:stocklite/features/milling/presentation/screens/milling_result_confirmation_screen.dart';

MillingOutputFormValue output(MillingOutputType type, double kg) =>
    MillingOutputFormValue(type: type, productVariantId: 1, locationId: 2, bagCount: 1, kgPerBag: kg, outputWeightKg: kg);

void main() {
  setUp(() {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: AuthUser(
        id: 1,
        fullName: 'Tester',
        email: 'test@example.com',
        permissions: [
          UserPermission(
            menuId: 61,
            menuCode: 'MILLING_ORDERS',
            actions: {'READ', 'UPDATE'},
          ),
        ],
      ),
    );
  });

  tearDown(() => AuthSessionStore.current = null);

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

  test('payload maps contract fields, machineRef and excludes kgPerBag', () {
    final payload = buildMillingCompletePayloadPreview(
      outputs: [output(MillingOutputType.rice, 10), output(MillingOutputType.husk, 2)],
      machineRef: 'MAY-XAY-02',
      note: null,
    );
    final rows = payload['outputs'] as List<dynamic>;
    expect(rows, hasLength(2));
    expect(rows.first, isNot(contains('kgPerBag')));
    expect(rows.last['outputType'], 'HUSK');
    expect(rows.last['isByproduct'], isTrue);
    expect(payload['machineRef'], 'MAY-XAY-02');
  });

  testWidgets(
      'calculates bag count from actual weight and renders machineRef input',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = _FakeConfirmRepository();
    const order = MillingOrder(
      id: 123,
      millingCode: 'MO-2026-123',
      warehouseId: 1,
      inputLotCode: 'LOT-01',
      inputWeightKg: 1000,
      warehouseZone: 'Khu A',
      locationCode: 'LOC-01',
      scaleCode: 'SCALE-01',
      totalRiceOutputKg: 680,
      yieldRateUsed: 0.68,
      machineRef: 'MAY-XAY-VIP',
      statusCode: 'IN_PROGRESS',
      riceBags: [],
      branBags: [],
      brokenBags: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MillingResultConfirmationScreen(
          order: order,
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify machineRef dropdown is rendered and prefilled
    expect(find.text('Mã máy xay'), findsOneWidget);
    expect(find.text('MAY-XAY-VIP'), findsOneWidget);

    // Verify Mass balance section is rendered with correct labels
    expect(find.text('Đối chiếu mẻ xay'), findsOneWidget);
    expect(find.text('Lúa đã giữ'), findsOneWidget);
    expect(find.text('Lúa thực tế sẽ trừ'), findsOneWidget);
    expect(find.text('Chênh cân bằng'), findsOneWidget);

    // Select Rice SKU (which has targetWeightKg = 50)
    await tester.tap(find.text('Chọn SKU').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('GAO-ST25-50').last);
    await tester.pumpAndSettle();

    // Verify kg/bao was auto-filled as 50
    expect(find.text('50'), findsOneWidget);

    // Enter actual output weight 500 kg
    final weightFinder =
        find.widgetWithText(TextField, 'Khối lượng thực tế (kg) *');
    expect(weightFinder, findsOneWidget);
    await tester.enterText(weightFinder, '500');
    await tester.pumpAndSettle();

    // Verify bag count was automatically calculated: 500 / 50 = 10 bags
    expect(find.text('10'), findsOneWidget);
  });
}

class _FakeConfirmRepository extends MockMillingRepository {
  @override
  Future<List<MillingProductOption>> getOutputProducts() async => const [
        MillingProductOption(
          id: 1,
          name: 'Gạo ST25 50kg',
          sku: 'GAO-ST25-50',
          outputType: 'RICE',
          targetWeightKg: 50.0,
        ),
        MillingProductOption(
          id: 2,
          name: 'Tấm ST25',
          sku: 'TAM-ST25',
          outputType: 'BROKEN',
          targetWeightKg: 25.0,
        ),
      ];

  @override
  Future<List<MillingPutawaySuggestion>> getPutawaySuggestions({
    required int warehouseId,
    required int productVariantId,
    required double requiredWeightKg,
  }) async =>
      const [
        MillingPutawaySuggestion(
          locationId: 10,
          locationCode: 'LOC-10',
          zoneName: 'Khu A',
          currentOccupancyKg: 0,
          maxCapacityKg: 5000,
          freeCapacityKg: 5000,
          isEmpty: true,
        ),
      ];
}
