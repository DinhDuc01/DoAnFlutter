import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/milling/data/api_milling_repository.dart';
import 'package:stocklite/features/milling/data/milling_repository.dart';
import 'package:stocklite/features/milling/models/milling_location.dart';
import 'package:stocklite/features/milling/models/milling_order.dart';
import 'package:stocklite/features/milling/models/milling_output_form.dart';
import 'package:stocklite/features/milling/presentation/screens/milling_result_confirmation_screen.dart';
import 'package:stocklite/features/milling/presentation/screens/milling_source_selection_screen.dart';

import 'support/fake_api_client.dart';

void main() {
  setUp(() {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'milling-token',
      refreshToken: 'refresh',
      user: AuthUser(id: 3, fullName: 'Tổ xay', email: 'xay@example.com'),
    );
  });
  tearDown(() => AuthSessionStore.current = null);

  group('getSourceSuggestion', () {
    Map<String, dynamic> lotResponse(int lotId, List<Map<String, dynamic>> bags) => {
          'isSucceeded': true,
          'resources': {'id': lotId, 'lotCode': 'LOT-$lotId', 'bags': bags},
        };

    test('ticks every suggested bag so the auto pick meets the requirement',
        () async {
      final client = FakeApiClient(
        onGet: (path, _, __) async {
          if (path.contains('/source-suggestions')) {
            return {
              'isSucceeded': true,
              'resources': {
                'requiredWeightKg': 100,
                'suggestedWeightKg': 100,
                'missingWeightKg': 0,
                'inputs': [
                  {'paddyLotId': 5, 'locationId': 12, 'bagIds': [101, 102]},
                ],
                'columns': [
                  {
                    'locationId': 12,
                    'locationCode': 'A01',
                    'suggestedWeightKg': 100,
                    'bagIds': [101, 102],
                  },
                ],
              },
            };
          }
          return lotResponse(5, [
            {'id': 101, 'bagNo': 1, 'weightKg': 50, 'status': 'Stored'},
            {'id': 102, 'bagNo': 2, 'weightKg': 50, 'status': 'Stored'},
          ]);
        },
      );

      final suggestion =
          await ApiMillingRepository(apiClient: client).getSourceSuggestion(21);

      expect(suggestion.requiredWeightKg, 100);
      expect(suggestion.columns.single.bags, hasLength(2));
      expect(
        suggestion.columns.single.bags.every((bag) => bag.selected),
        isTrue,
      );
      // Đủ khối lượng ngay khi mở màn -> nút giữ lúa không còn bị khoá.
      expect(suggestion.selectedWeightKg, 100);
      expect(suggestion.isComplete, isTrue);
    });

    test('keeps bags of every lot inside one column, not just the first',
        () async {
      final client = FakeApiClient(
        onGet: (path, _, __) async {
          if (path.contains('/source-suggestions')) {
            return {
              'isSucceeded': true,
              'resources': {
                'requiredWeightKg': 100,
                'suggestedWeightKg': 100,
                'missingWeightKg': 0,
                // Cùng một cột nhưng hai lô khác nhau — bản cũ chỉ lấy lô đầu.
                'inputs': [
                  {'paddyLotId': 5, 'locationId': 12, 'bagIds': [101]},
                  {'paddyLotId': 6, 'locationId': 12, 'bagIds': [102]},
                ],
                'columns': [
                  {
                    'locationId': 12,
                    'locationCode': 'A01',
                    'suggestedWeightKg': 100,
                    'bagIds': [101, 102],
                  },
                ],
              },
            };
          }
          if (path.endsWith('/paddy-lots/5')) {
            return lotResponse(5, [
              {'id': 101, 'bagNo': 1, 'weightKg': 50, 'status': 'Stored'},
            ]);
          }
          return lotResponse(6, [
            {'id': 102, 'bagNo': 7, 'weightKg': 50, 'status': 'Stored'},
          ]);
        },
      );

      final suggestion =
          await ApiMillingRepository(apiClient: client).getSourceSuggestion(21);

      expect(suggestion.selectedWeightKg, 100);
      expect(
        suggestion.columns.single.bags.map((bag) => bag.bagNo),
        [1, 7],
      );
    });

    test('surfaces the missing weight when the source is not enough', () async {
      final client = FakeApiClient(
        onGet: (path, _, __) async {
          if (path.contains('/source-suggestions')) {
            return {
              'isSucceeded': true,
              'resources': {
                'requiredWeightKg': 100,
                'suggestedWeightKg': 50,
                'missingWeightKg': 50,
                'inputs': [
                  {'paddyLotId': 5, 'locationId': 12, 'bagIds': [101]},
                ],
                'columns': [
                  {
                    'locationId': 12,
                    'suggestedWeightKg': 50,
                    'bagIds': [101],
                  },
                ],
              },
            };
          }
          return lotResponse(5, [
            {'id': 101, 'bagNo': 1, 'weightKg': 50, 'status': 'Stored'},
          ]);
        },
      );

      final suggestion =
          await ApiMillingRepository(apiClient: client).getSourceSuggestion(21);

      expect(suggestion.isComplete, isFalse);
      expect(suggestion.missingWeightKg, 50);
    });
  });

  testWidgets('the read-only source view never calls the suggestion API',
      (tester) async {
    final repository = _ReservedSourceRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: MillingSourceSelectionScreen(
          order: _order('IN_PROGRESS'),
          repository: repository,
          readOnly: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Backend chỉ gợi ý nguồn cho lệnh Nháp/Đã giữ nên gọi ở đây là 422.
    expect(repository.suggestionCalls, 0);
    expect(repository.detailCalls, 1);
    expect(find.textContaining('Bao #1'), findsOneWidget);
    expect(find.textContaining('Bao #2'), findsOneWidget);
    expect(find.textContaining('đã khóa nguồn lúa'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('entering results auto-picks the suggested putaway location',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _PutawayRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MillingResultConfirmationScreen(
          order: _order('IN_PROGRESS'),
          repository: repository,
          initialOutputForms: const [
            MillingOutputFormValue(
              type: MillingOutputType.rice,
              productVariantId: 101,
              bagCount: 2,
              kgPerBag: 25,
              outputWeightKg: 50,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tự gọi API gợi ý và gán luôn vị trí tốt nhất, không bắt bấm chọn tay.
    expect(repository.putawayCalls, 1);
    expect(repository.lastRequiredKg, 50);
    expect(find.textContaining('Vị trí: A-01'), findsOneWidget);
    expect(find.text('Chọn vị trí nhập kho *'), findsNothing);
  });
}

MillingOrder _order(
  String statusCode, {
  List<MillingOrderInput> inputs = const [],
}) =>
    MillingOrder(
      id: 21,
      millingCode: 'MO-21',
      inputLotCode: 'LOT-01',
      inputWeightKg: 100,
      warehouseZone: 'Kho A',
      locationCode: 'A01',
      scaleCode: 'Cân thủ công',
      riceBags: const [],
      branBags: const [],
      statusCode: statusCode,
      statusName: statusCode,
      warehouseId: 7,
      riceVarietyName: 'OM5451',
      computedPaddyKg: 100,
      yieldRateUsed: 0.5,
      riceProductVariantId: 101,
      inputs: inputs,
    );

class _ReservedSourceRepository extends MockMillingRepository {
  int suggestionCalls = 0;
  int detailCalls = 0;

  @override
  Future<MillingSourceSuggestion> getSourceSuggestion(int orderId) async {
    suggestionCalls++;
    throw const MillingApiException(
      'Chỉ có thể gợi ý nguồn lúa cho lệnh Nháp/Đã giữ.',
    );
  }

  @override
  Future<MillingOrder> getMillingOrderDetail(int id) async {
    detailCalls++;
    return _order(
      'IN_PROGRESS',
      inputs: const [
        MillingOrderInput(
          id: 1,
          paddyLotId: 5,
          consumedWeightKg: 100,
          lotCode: 'LOT-05',
          locationId: 12,
          locationCode: 'A01',
          reservedWeightKg: 100,
          bags: [
            MillingSelectedBag(
              bagId: 101,
              bagNo: 1,
              weightKg: 50,
              stackOrder: 2,
              status: 'Stored',
            ),
            MillingSelectedBag(
              bagId: 102,
              bagNo: 2,
              weightKg: 50,
              stackOrder: 1,
              status: 'Stored',
            ),
          ],
        ),
      ],
    );
  }
}

class _PutawayRepository extends MockMillingRepository {
  int putawayCalls = 0;
  double? lastRequiredKg;

  @override
  Future<List<MillingProductOption>> getOutputProducts() async => const [
        MillingProductOption(
          id: 101,
          sku: 'RICE-001',
          name: 'Gạo thành phẩm',
          outputType: 'RICE',
        ),
      ];

  @override
  Future<List<MillingPutawaySuggestion>> getPutawaySuggestions({
    required int warehouseId,
    required int productVariantId,
    required double requiredWeightKg,
  }) async {
    putawayCalls++;
    lastRequiredKg = requiredWeightKg;
    return const [
      MillingPutawaySuggestion(
        locationId: 44,
        locationCode: 'A-01',
        zoneName: 'Khu A',
        currentOccupancyKg: 100,
        maxCapacityKg: 1000,
        freeCapacityKg: 900,
        isEmpty: false,
        reason: 'Cùng loại hàng',
      ),
    ];
  }
}
