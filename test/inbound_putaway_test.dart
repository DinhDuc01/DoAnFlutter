import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/inbound/data/inbound_order_repository.dart';
import 'package:stocklite/features/inbound/models/bag_putaway_planner.dart';
import 'package:stocklite/features/inbound/models/inbound_order.dart';
import 'package:stocklite/features/inbound/presentation/screens/inbound_putaway_line_screen.dart';

import 'support/fake_api_client.dart';

void main() {
  setUp(() {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'inbound-token',
      refreshToken: 'refresh',
      user: AuthUser(
        id: 7,
        fullName: 'Thủ kho',
        email: 'kho@example.com',
        permissions: [
          UserPermission(
            menuId: 1,
            menuCode: 'INBOUND_ORDERS',
            actions: {'READ', 'UPDATE'},
          ),
        ],
      ),
    );
  });
  tearDown(() => AuthSessionStore.current = null);

  group('ApiInboundOrderRepository', () {
    test('keeps only paddy lines from putaway-pending', () async {
      final client = FakeApiClient(
        onGet: (path, _, token) async {
          expect(path, '/api/v1/inbound-orders/putaway-pending');
          expect(token, 'inbound-token');
          return {
            'isSucceeded': true,
            'resources': [
              {
                'id': 1,
                'poCode': 'PO-01',
                'warehouseId': 3,
                'sourceType': 'RECEIPT',
                'inboundOrderStatusCode': 'Approved',
                'items': [
                  {
                    'id': 11,
                    'inboundOrderId': 1,
                    'paddyLotId': 5,
                    'paddyLotCode': 'LOT-01',
                    'quantityOrdered': 1000,
                    'quantityReceived': 200,
                    'receiptStatus': 'Pending',
                  },
                ],
              },
              {
                'id': 2,
                'poCode': 'PO-02',
                'warehouseId': 3,
                'sourceType': 'PURCHASE',
                'note': 'Bao bì nhựa',
                'items': [
                  {
                    'id': 22,
                    'inboundOrderId': 2,
                    'productVariantName': 'Bao PP',
                    'quantityOrdered': 10,
                    'quantityReceived': 0,
                    'receiptStatus': 'Pending',
                  },
                ],
              },
            ],
          };
        },
      );

      final lines = await ApiInboundOrderRepository(apiClient: client)
          .getPutawayPending();

      expect(lines, hasLength(1));
      expect(lines.single.item.paddyLotCode, 'LOT-01');
      expect(lines.single.item.remainingKg, 800);
    });

    test('submits a draft order without touching the approve endpoint',
        () async {
      final client =
          FakeApiClient(onPost: (_, __, ___) async => {'isSucceeded': true});

      await ApiInboundOrderRepository(apiClient: client).submit(9);

      expect(client.calls.single.path, '/api/v1/inbound-orders/9/submit');
      expect(
        client.calls.any((call) => call.path.contains('/approve')),
        isFalse,
      );
    });

    test('sends the bag columns when confirming a receipt', () async {
      final client =
          FakeApiClient(onPost: (_, __, ___) async => {'isSucceeded': true});

      await ApiInboundOrderRepository(apiClient: client).confirmReceipt(
        9,
        11,
        operationKey: 'op-1',
        columns: const [
          BagPutawayColumn(
            locationId: 4,
            slotCode: 'A-01',
            bags: [
              BagPutawayBag(id: 101, bagNo: 1, weightKg: 50),
              BagPutawayBag(id: 102, bagNo: 2, weightKg: 50),
            ],
            totalKg: 100,
            capacityRemainAfter: 400,
          ),
        ],
      );

      final call = client.calls.single;
      expect(call.path, '/api/v1/inbound-orders/9/receipts/11/confirm');
      expect(call.body!['operationKey'], 'op-1');
      final columns = call.body!['columns'] as List;
      expect(columns.single['locationId'], 4);
      expect(columns.single['bagIds'], [101, 102]);
    });

    test('propagates the backend message on failure', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'isSucceeded': false,
          'message': 'Vị trí đã đầy',
        },
      );

      await expectLater(
        ApiInboundOrderRepository(apiClient: client).submit(9),
        throwsA(
          isA<InboundOrderException>().having(
            (error) => error.message,
            'message',
            'Vị trí đã đầy',
          ),
        ),
      );
    });
  });

  group('BagPutawayPlanner', () {
    BagPutawayPlan plan() => const BagPutawayPlan(
          columns: [
            BagPutawayColumn(
              locationId: 1,
              slotCode: 'A-01',
              // Đáy -> đỉnh: 2 bao 50kg rồi 1 bao 30kg trên cùng.
              bags: [
                BagPutawayBag(id: 1, bagNo: 1, weightKg: 50),
                BagPutawayBag(id: 2, bagNo: 2, weightKg: 50),
                BagPutawayBag(id: 3, bagNo: 3, weightKg: 30),
              ],
              totalKg: 130,
              capacityRemainAfter: 70,
            ),
          ],
          candidateLocations: [
            BagPutawayCandidate(
              locationId: 1,
              slotCode: 'A-01',
              capacityAvailableKg: 200,
              priority: 5,
            ),
            BagPutawayCandidate(
              locationId: 2,
              slotCode: 'A-02',
              capacityAvailableKg: 60,
              priority: 3,
            ),
          ],
          unplacedBagIds: [],
        );

    test('groups only consecutive bags of the same weight, top first', () {
      final groups =
          BagPutawayPlanner.columnGroups(plan().columns.first, plan());

      expect(groups, hasLength(2));
      // Nhóm đầu tiên hiển thị là ĐỈNH cột (STT ưu tiên 1).
      expect(groups.first.count, 1);
      expect(groups.first.weightKg, 30);
      expect(groups.first.priorityLabel, '1');
      expect(groups.last.count, 2);
      expect(groups.last.priorityLabel, '2–3');
      // Bao 50kg xuất hiện nhiều nhất nên là bao "chuẩn".
      expect(groups.last.isStandardWeight, isTrue);
      expect(groups.first.isStandardWeight, isFalse);
    });

    test('moves a group to the bottom of its own column', () {
      final result = BagPutawayPlanner.moveGroupOrder(
        plan(),
        1,
        const [3],
        toTop: false,
      );

      expect(result.isChanged, isTrue);
      expect(
        result.plan.columns.first.bagIds,
        [3, 1, 2],
      );
    });

    test('refuses to move a group into a column without capacity', () {
      final result =
          BagPutawayPlanner.moveGroupToLocation(plan(), const [1, 2], 2);

      expect(result.isChanged, isFalse);
      expect(result.error, contains('không đủ sức chứa'));
      expect(result.plan.columns.first.bags, hasLength(3));
    });

    test('moves a fitting group and keeps LIFO order in the target column', () {
      final result =
          BagPutawayPlanner.moveGroupToLocation(plan(), const [3], 2);

      expect(result.isChanged, isTrue);
      final source =
          result.plan.columns.firstWhere((column) => column.locationId == 1);
      final target =
          result.plan.columns.firstWhere((column) => column.locationId == 2);
      expect(source.bagIds, [1, 2]);
      expect(source.totalKg, 100);
      expect(target.bagIds, [3]);
      expect(target.totalKg, 30);
      expect(target.capacityRemainAfter, 30);
    });

    test('orders suggestions by the plan candidate ranking', () {
      final ordered = BagPutawayPlanner.orderSuggestionsByPlan(
        const [
          PutawaySuggestion(
            locationId: 2,
            score: 1,
            availableCapacity: 60,
            currentOccupancy: 40,
            priority: 3,
            categoryMatch: false,
            recommendedWeightKg: 60,
            canFitWhole: false,
            isQuarantine: false,
          ),
          PutawaySuggestion(
            locationId: 1,
            score: 2,
            availableCapacity: 200,
            currentOccupancy: 0,
            priority: 5,
            categoryMatch: true,
            recommendedWeightKg: 130,
            canFitWhole: true,
            isQuarantine: false,
          ),
        ],
        plan(),
      );

      expect(ordered.map((item) => item.locationId), [1, 2]);
      expect(ordered.first.occupancyPercent, 0);
    });
  });

  group('InboundPutawayLineScreen', () {
    InboundPutawayLine line(
      String statusCode, {
      String receiptStatus = 'Pending',
      double received = 0,
    }) =>
        InboundPutawayLine(
          order: InboundOrder(
            id: 1,
            poCode: 'PO-01',
            warehouseId: 3,
            warehouseName: 'Kho A',
            statusName: statusCode,
            statusCode: statusCode,
          ),
          item: InboundOrderItem(
            id: 11,
            inboundOrderId: 1,
            quantityOrdered: 1000,
            quantityReceived: received,
            receiptStatus: receiptStatus,
            paddyLotCode: 'LOT-01',
          ),
        );

    testWidgets('a submitted order can not be approved from mobile',
        (tester) async {
      final repository = _FakeInboundRepository(
        suggestions: const [_testPutawaySuggestion],
        bagPlan: _testBagPlan,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: InboundPutawayLineScreen(
            line: line('Submitted'),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('chờ người khác phê duyệt'), findsWidgets);
      expect(find.text('Phương án xếp nguyên bao'), findsOneWidget);
      expect(find.text('Phê duyệt phiếu'), findsNothing);
      expect(find.text('Gửi duyệt phiếu'), findsNothing);
      expect(find.textContaining('Xác nhận xếp'), findsNothing);
      // Chờ duyệt chỉ tải dữ liệu xem trước, không chạy mutation nhận hàng.
      expect(repository.startedReceipts, isEmpty);
      expect(repository.recordedQuantities, isEmpty);
      expect(repository.suggestionCalls, 1);
    });

    testWidgets('a draft order only offers sending it for approval',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InboundPutawayLineScreen(
            line: line('Draft'),
            repository: _FakeInboundRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gửi duyệt phiếu'), findsOneWidget);
      expect(find.text('Phê duyệt phiếu'), findsNothing);
    });

    testWidgets(
        'an approved order goes straight to the whole-bag plan, '
        'without the receive / load-locations buttons', (tester) async {
      final repository = _FakeInboundRepository(
        // Sau khi nhận hàng, backend trả phiếu ở trạng thái đang nhận.
        lines: [line('Receiving', receiptStatus: 'QuantityEntered')],
        suggestions: const [
          PutawaySuggestion(
            locationId: 4,
            score: 9,
            availableCapacity: 2000,
            currentOccupancy: 500,
            priority: 5,
            categoryMatch: true,
            recommendedWeightKg: 1000,
            canFitWhole: true,
            isQuarantine: false,
            zoneName: 'A',
            slotCode: 'A-01',
          ),
        ],
        bagPlan: const BagPutawayPlan(
          columns: [
            BagPutawayColumn(
              locationId: 4,
              slotCode: 'A-01',
              bags: [
                BagPutawayBag(id: 101, bagNo: 1, weightKg: 1000),
              ],
              totalKg: 1000,
              capacityRemainAfter: 1000,
              priorityRank: 1,
            ),
          ],
          candidateLocations: [
            BagPutawayCandidate(
              locationId: 4,
              slotCode: 'A-01',
              capacityAvailableKg: 2000,
              priority: 5,
            ),
          ],
          unplacedBagIds: [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InboundPutawayLineScreen(
            line: line('Approved'),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chuỗi nhận hàng chạy tự động, đúng như web làm ngay sau khi duyệt.
      expect(repository.startedReceipts, [11]);
      expect(repository.recordedQuantities, [1000.0]);
      expect(repository.suggestionCalls, 1);

      // Hai nút thao tác từng bước của bản cũ không còn.
      expect(find.text('Bắt đầu nhận hàng'), findsNothing);
      expect(find.text('Tải vị trí gợi ý'), findsNothing);

      // API trả kế hoạch bao thì chỉ render phương án xếp nguyên bao.
      expect(find.text('Phương án xếp nguyên bao'), findsOneWidget);
      expect(find.textContaining('Ưu tiên 1'), findsOneWidget);
      expect(find.textContaining('A-01'), findsWidgets);
      expect(find.textContaining('Xác nhận xếp'), findsOneWidget);
      expect(find.text('Vị trí đề xuất'), findsNothing);
    });

    testWidgets(
        'missing bag plan shows the backend-plan error, not simple suggestions',
        (tester) async {
      final repository = _FakeInboundRepository(
        lines: [line('Receiving', receiptStatus: 'QuantityEntered')],
        suggestions: const [
          PutawaySuggestion(
            locationId: 4,
            score: 9,
            availableCapacity: 2000,
            currentOccupancy: 500,
            priority: 5,
            categoryMatch: true,
            recommendedWeightKg: 1000,
            canFitWhole: true,
            isQuarantine: false,
            zoneName: 'A',
            slotCode: 'A-01',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InboundPutawayLineScreen(
            line: line('Approved'),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Không có phương án xếp nguyên bao'),
          findsOneWidget);
      expect(find.text('Vị trí đề xuất'), findsNothing);
      expect(find.textContaining('Xác nhận xếp'), findsNothing);
      expect(find.text('Thử lại'), findsOneWidget);
    });
    testWidgets('READ-only session never starts the inbound mutation chain',
        (tester) async {
      AuthSessionStore.current = const AuthSession(
        accessToken: 'read-token',
        refreshToken: 'refresh',
        user: AuthUser(
          id: 8,
          fullName: 'Read only',
          email: 'read@example.com',
          permissions: [
            UserPermission(
              menuId: 1,
              menuCode: 'INBOUND_ORDERS',
              actions: {'READ'},
            ),
          ],
        ),
      );
      final repository = _FakeInboundRepository(
        suggestions: const [_testPutawaySuggestion],
        bagPlan: _testBagPlan,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: InboundPutawayLineScreen(
            line: line('Approved'),
            repository: repository,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.startedReceipts, isEmpty);
      expect(repository.recordedQuantities, isEmpty);
      expect(repository.suggestionCalls, 1);
      expect(repository.submitCalls, 0);
      expect(find.text('Phương án xếp nguyên bao'), findsOneWidget);
      expect(find.textContaining('Xác nhận xếp'), findsNothing);
    });
  });
}

const _testPutawaySuggestion = PutawaySuggestion(
  locationId: 4,
  score: 9,
  availableCapacity: 2000,
  currentOccupancy: 500,
  priority: 5,
  categoryMatch: true,
  recommendedWeightKg: 1000,
  canFitWhole: true,
  isQuarantine: false,
  zoneName: 'A',
  slotCode: 'A-01',
);

const _testBagPlan = BagPutawayPlan(
  columns: [
    BagPutawayColumn(
      locationId: 4,
      slotCode: 'A-01',
      bags: [BagPutawayBag(id: 101, bagNo: 1, weightKg: 1000)],
      totalKg: 1000,
      capacityRemainAfter: 1000,
      priorityRank: 1,
    ),
  ],
  candidateLocations: [
    BagPutawayCandidate(
      locationId: 4,
      slotCode: 'A-01',
      capacityAvailableKg: 2000,
      priority: 5,
    ),
  ],
  unplacedBagIds: [],
);

class _FakeInboundRepository implements InboundOrderRepository {
  _FakeInboundRepository({
    this.suggestions = const <PutawaySuggestion>[],
    this.lines = const <InboundPutawayLine>[],
    this.bagPlan,
  });

  final List<PutawaySuggestion> suggestions;
  final List<InboundPutawayLine> lines;
  final BagPutawayPlan? bagPlan;

  final List<int> startedReceipts = <int>[];
  final List<double> recordedQuantities = <double>[];
  int suggestionCalls = 0;
  int submitCalls = 0;

  @override
  Future<List<InboundPutawayLine>> getPutawayPending() async => lines;

  @override
  Future<List<StorageLocation>> getLocations() async =>
      const <StorageLocation>[];

  @override
  Future<void> submit(int orderId) async {
    submitCalls++;
  }

  @override
  Future<void> startReceipt(int orderId, int itemId) async {
    startedReceipts.add(itemId);
  }

  @override
  Future<void> recordQuantity(
    int orderId,
    int itemId,
    double quantityReceived,
  ) async {
    recordedQuantities.add(quantityReceived);
  }

  @override
  Future<List<PutawaySuggestion>> getPutawaySuggestions(
    int orderId,
    int itemId,
  ) async {
    suggestionCalls++;
    return suggestions;
  }

  @override
  Future<BagPutawayPlan?> getBagPutawayPlan(int orderId, int itemId) async =>
      bagPlan;

  @override
  Future<void> selectPutaway(
    int orderId,
    int itemId, {
    required int locationId,
    required bool isOverride,
    String? overrideReason,
    double? weightKg,
  }) async {}

  @override
  Future<void> confirmReceipt(
    int orderId,
    int itemId, {
    required String operationKey,
    List<BagPutawayColumn>? columns,
  }) async {}
}
