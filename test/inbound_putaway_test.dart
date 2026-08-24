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
      expect(find.text('Vị trí đề xuất'), findsOneWidget);
      expect(find.text('Phê duyệt phiếu'), findsNothing);
      expect(find.text('Gửi duyệt phiếu'), findsNothing);
      expect(find.textContaining('Xác nhận xếp'), findsNothing);
      // Chờ duyệt chỉ tải dữ liệu xem trước, không chạy mutation nhận hàng.
      expect(repository.startedReceipts, isEmpty);
      expect(repository.recordedQuantities, isEmpty);
      expect(repository.suggestionCalls, 1);
      expect(repository.bagPlanCalls, 0);
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
      expect(repository.bagPlanCalls, 1);
      expect(find.text('Phương án xếp nguyên bao'), findsOneWidget);
      expect(find.textContaining('Ưu tiên 1'), findsOneWidget);
      expect(find.textContaining('A-01'), findsWidgets);
      expect(find.textContaining('Xác nhận xếp'), findsOneWidget);
      expect(find.text('Vị trí đề xuất'), findsNothing);
    });

    testWidgets(
        'missing bag plan falls back to suggestions and allows selecting location and confirming',
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

      expect(find.text('Vị trí đề xuất'), findsOneWidget);
      expect(find.textContaining('A-01'), findsOneWidget);
      expect(find.textContaining('Xác nhận xếp 1.000 kg'), findsOneWidget);
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
      expect(repository.bagPlanCalls, 0);
      expect(find.text('Vị trí đề xuất'), findsOneWidget);
      expect(find.textContaining('Xác nhận xếp'), findsNothing);
    });

    testWidgets(
        'READ-only falls back to eligible warehouse locations when suggestions are empty',
        (tester) async {
      AuthSessionStore.current = _readOnlyInboundSession;
      final repository = _FakeInboundRepository(
        locations: const [_eligibleWarehouseLocation],
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

      expect(find.textContaining('A-A08'), findsOneWidget);
      expect(find.textContaining('Khu/cột còn chỗ'), findsOneWidget);
      expect(repository.suggestionCalls, 1);
      expect(repository.startedReceipts, isEmpty);
      expect(repository.recordedQuantities, isEmpty);
      expect(find.textContaining('Xác nhận xếp'), findsNothing);
    });

    testWidgets(
        'READ-only keeps warehouse fallback when suggestion endpoint fails',
        (tester) async {
      AuthSessionStore.current = _readOnlyInboundSession;
      final repository = _FakeInboundRepository(
        locations: const [_eligibleWarehouseLocation],
        suggestionError: const InboundOrderException('Suggestion unavailable'),
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

      expect(find.textContaining('A-A08'), findsOneWidget);
      expect(find.textContaining('Không tải được vị trí gợi ý'), findsNothing);
      expect(repository.startedReceipts, isEmpty);
      expect(repository.recordedQuantities, isEmpty);
    });

    testWidgets('suggestions are ranked first and locations are deduplicated',
        (tester) async {
      AuthSessionStore.current = _readOnlyInboundSession;
      final repository = _FakeInboundRepository(
        suggestions: const [_testPutawaySuggestion],
        locations: const [
          _suggestedWarehouseLocation,
          _eligibleWarehouseLocation,
        ],
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

      expect(find.textContaining('Ưu tiên 1'), findsOneWidget);
      expect(find.textContaining('Các khu/cột phù hợp khác'), findsOneWidget);
      expect(find.textContaining('A-A08'), findsOneWidget);
      // Location id=4 đã xuất hiện trong API suggestion nên không render lại
      // thành một card fallback thứ hai.
      expect(find.text('A-A01'), findsNothing);
    });

    testWidgets(
        'full putaway confirms once, immediately completes, and does not reload pending/suggestions or show warnings',
        (tester) async {
      final repository = _FakeInboundRepository(
        lines: [line('Receiving', receiptStatus: 'QuantityEntered', received: 0)],
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

      // Ghi lại số lần gọi trước khi bấm xác nhận
      final pendingCallsBeforeConfirm = repository.pendingCalls;
      final suggestionCallsBeforeConfirm = repository.suggestionCalls;
      final bagPlanCallsBeforeConfirm = repository.bagPlanCalls;

      // Tìm nút "Xác nhận xếp ..." ở bottom bar
      final confirmBtn = find.textContaining('Xác nhận xếp');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Hiện dialog xác nhận
      expect(find.text('Xác nhận nhập kho?'), findsOneWidget);
      final dialogConfirmBtn = find.widgetWithText(FilledButton, 'Xác nhận');
      expect(dialogConfirmBtn, findsOneWidget);
      await tester.tap(dialogConfirmBtn);
      await tester.pumpAndSettle();

      // 1. Gọi API confirm đúng một lần
      expect(repository.confirmReceiptCalls, 1);

      // 2. Không gọi lại pending list sau khi confirm hoàn tất
      expect(repository.pendingCalls, pendingCallsBeforeConfirm);

      // 3. Không gọi lại suggestion và bag-plan sau khi confirm hoàn tất
      expect(repository.suggestionCalls, suggestionCallsBeforeConfirm);
      expect(repository.bagPlanCalls, bagPlanCallsBeforeConfirm);

      // 4. Không hiển thị cảnh báo/lỗi gợi ý xếp vị trí
      expect(find.textContaining('Không tải được vị trí gợi ý'), findsNothing);
      expect(find.textContaining('Màn này yêu cầu phương án xếp nguyên bao'), findsNothing);
      expect(find.text('Thử lại'), findsNothing);

      // 5. Hiển thị trạng thái/thông báo hoàn tất
      expect(find.text('Đã hoàn tất nhập kho'), findsOneWidget);
      expect(find.text('Đã hoàn tất nhập kho lô hàng.'), findsWidgets);
    });

    testWidgets(
        'partial putaway confirms once, reloads pending and prepares next putaway',
        (tester) async {
      final repository = _FakeInboundRepository(
        lines: [
          line('Receiving', receiptStatus: 'QuantityEntered', received: 400),
        ],
        suggestions: const [
          PutawaySuggestion(
            locationId: 4,
            score: 9,
            availableCapacity: 2000,
            currentOccupancy: 500,
            priority: 5,
            categoryMatch: true,
            recommendedWeightKg: 400,
            canFitWhole: false,
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
                BagPutawayBag(id: 101, bagNo: 1, weightKg: 400),
              ],
              totalKg: 400,
              capacityRemainAfter: 1600,
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
            line: line('Receiving', received: 0),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pendingCallsBeforeConfirm = repository.pendingCalls;

      final confirmBtn = find.textContaining('Xác nhận xếp');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      final dialogConfirmBtn = find.widgetWithText(FilledButton, 'Xác nhận');
      await tester.tap(dialogConfirmBtn);
      await tester.pumpAndSettle();

      expect(repository.confirmReceiptCalls, 1);
      // Nhập một phần thì vẫn reload pending để chuẩn bị cho phần còn lại
      expect(repository.pendingCalls, greaterThan(pendingCallsBeforeConfirm));
    });

    testWidgets(
        'reload pending returning empty line keeps completed state and does not error',
        (tester) async {
      final repository = _FakeInboundRepository(
        lines: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InboundPutawayLineScreen(
            line: line('Completed', received: 1000),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đã hoàn tất nhập kho'), findsOneWidget);
      expect(find.textContaining('Không tải được'), findsNothing);
      expect(repository.suggestionCalls, 0);
      expect(repository.bagPlanCalls, 0);
    });

    testWidgets(
        'double tap confirmation triggers API confirm mutation only once',
        (tester) async {
      final repository = _FakeInboundRepository(
        lines: [
          line('Receiving', receiptStatus: 'QuantityEntered', received: 0)
        ],
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
      await tester.pumpAndSettle();

      final confirmBtn = find.textContaining('Xác nhận xếp');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      final dialogConfirmBtn = find.widgetWithText(FilledButton, 'Xác nhận');
      // Nhấp đúp nhanh vào nút Xác nhận
      await tester.tap(dialogConfirmBtn);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();

      expect(repository.confirmReceiptCalls, 1);
      expect(find.text('Đã hoàn tất nhập kho'), findsOneWidget);
    });

    testWidgets(
        'after completion, realtime changes do not reload line or refetch suggestions',
        (tester) async {
      final repository = _FakeInboundRepository(
        lines: [
          line('Receiving', receiptStatus: 'QuantityEntered', received: 0)
        ],
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
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Xác nhận xếp'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
      await tester.pumpAndSettle();

      expect(repository.confirmReceiptCalls, 1);
      final pendingCallsAfterSuccess = repository.pendingCalls;
      final suggestionCallsAfterSuccess = repository.suggestionCalls;

      // Kích hoạt realtime event sau khi đã xong
      final state =
          tester.state(find.byType(InboundPutawayLineScreen)) as dynamic;
      state.onRealtimeChanged();
      await tester.pumpAndSettle();

      expect(repository.pendingCalls, pendingCallsAfterSuccess);
      expect(repository.suggestionCalls, suggestionCallsAfterSuccess);
      expect(find.text('Đã hoàn tất nhập kho'), findsOneWidget);
    });

    testWidgets(
        'disposing widget while async request is running does not throw or call setState after dispose',
        (tester) async {
      final repository = _FakeInboundRepository(
        lines: [line('Approved')],
        delay: const Duration(milliseconds: 100),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InboundPutawayLineScreen(
            line: line('Approved'),
            repository: repository,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));

      // Hủy widget bằng cách mount màn khác
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Màn hình khác')),
        ),
      );
      // Chờ các timer nền hoàn tất
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Màn hình khác'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'confirm failure (409 conflict or 500) displays error banner, keeps state, and does not mark finished',
        (tester) async {
      final repository = _FakeInboundRepository(
        lines: [
          line('Receiving', receiptStatus: 'QuantityEntered', received: 0)
        ],
        suggestions: const [_testPutawaySuggestion],
        bagPlan: _testBagPlan,
        confirmError:
            const InboundOrderException('Xung đột vị trí kho', statusCode: 409),
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

      await tester.tap(find.textContaining('Xác nhận xếp'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
      await tester.pumpAndSettle();

      expect(repository.confirmReceiptCalls, 1);
      expect(find.text('Đã hoàn tất nhập kho'), findsNothing);
      expect(find.textContaining('Xung đột vị trí kho'), findsOneWidget);
      // Không tự retry
      expect(repository.confirmReceiptCalls, 1);
    });

    testWidgets(
        'didUpdateWidget resets finished state when switching to a different active line',
        (tester) async {
      const activeLine = InboundPutawayLine(
        order: InboundOrder(
            id: 2, poCode: 'PO-02', warehouseId: 3, statusCode: 'Approved'),
        item: InboundOrderItem(
          id: 22,
          inboundOrderId: 2,
          quantityOrdered: 500,
          quantityReceived: 0,
          receiptStatus: 'QuantityEntered',
        ),
      );

      final repository = _FakeInboundRepository(
        lines: [activeLine],
        suggestions: const [_testPutawaySuggestion],
        bagPlan: _testBagPlan,
      );

      // Bắt đầu bằng 1 lô đã xong (id=11)
      const completedLine = InboundPutawayLine(
        order: InboundOrder(id: 1, poCode: 'PO-01', warehouseId: 3),
        item: InboundOrderItem(
          id: 11,
          inboundOrderId: 1,
          quantityOrdered: 1000,
          quantityReceived: 1000,
          receiptStatus: 'Confirmed',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InboundPutawayLineScreen(
            line: completedLine,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đã hoàn tất nhập kho'), findsOneWidget);

      // Chuyển sang một lô khác chưa xong (id=22)
      await tester.pumpWidget(
        MaterialApp(
          home: InboundPutawayLineScreen(
            line: activeLine,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PO-02'), findsWidgets);
      expect(find.text('Đã hoàn tất nhập kho'), findsNothing);
    });

    testWidgets(
        'Facility Owner (Chủ cơ sở with APPROVE permission) can load screen, view suggestions and confirm',
        (tester) async {
      AuthSessionStore.current = const AuthSession(
        accessToken: 'owner-token',
        refreshToken: 'refresh',
        user: AuthUser(
          id: 10,
          fullName: 'Chủ cơ sở',
          email: 'owner@example.com',
          roles: [UserRole(id: 1004, code: 'OWNER', name: 'Chủ cơ sở')],
          permissions: [
            UserPermission(
              menuId: 1,
              menuCode: 'INBOUND_ORDERS',
              actions: {'READ', 'APPROVE'},
            ),
          ],
        ),
      );

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

      expect(find.text('Vị trí đề xuất'), findsOneWidget);
      expect(find.textContaining('Xác nhận xếp 1.000 kg'), findsOneWidget);
    });

    testWidgets(
        'tapping retry when suggestion fails retries preparation and loads plan',
        (tester) async {
      var fail = true;
      final repository = _FakeInboundRepository(
        lines: [line('Approved')],
        bagPlan: _testBagPlan,
        onGetSuggestions: () {
          if (fail) {
            fail = false;
            throw const InboundOrderException(
              'Lỗi mạng tạm thời',
              statusCode: 500,
            );
          }
          return const [_testPutawaySuggestion];
        },
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

      // Hiện nút Thử lại
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.textContaining('Lỗi mạng tạm thời'), findsOneWidget);

      // Bấm Thử lại
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      // Đã lấy được phương án và sẵn sàng xác nhận
      expect(find.text('Thử lại'), findsNothing);
      expect(find.textContaining('Xác nhận xếp'), findsOneWidget);
    });

    test(
        'InboundOrder and InboundOrderItem handle missing or null json fields safely',
        () {
      final order = InboundOrder.fromJson(const {});
      expect(order.id, 0);
      expect(order.poCode, '');
      expect(order.items, isEmpty);
      expect(order.normalizedStatus, '');

      final item = InboundOrderItem.fromJson(const {});
      expect(item.id, 0);
      expect(item.remainingKg, 0);
      expect(item.needsQuarantine, isFalse);
      expect(item.quantityCaptured, isFalse);
    });
  });
}

const _readOnlyInboundSession = AuthSession(
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

const _eligibleWarehouseLocation = StorageLocation(
  id: 8,
  warehouseId: 3,
  zoneName: 'A',
  slotCode: 'A-A08',
  isActive: true,
  maxCapacity: 10000,
  currentOccupancy: 774,
  priority: 3,
);

const _suggestedWarehouseLocation = StorageLocation(
  id: 4,
  warehouseId: 3,
  zoneName: 'A',
  slotCode: 'A-A01',
  isActive: true,
  maxCapacity: 2500,
  currentOccupancy: 500,
  priority: 5,
);

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
    this.locations = const <StorageLocation>[],
    this.bagPlan,
    this.suggestionError,
    this.confirmError,
    this.delay,
    this.onGetBagPlan,
    this.onGetSuggestions,
  });

  final List<PutawaySuggestion> suggestions;
  final List<InboundPutawayLine> lines;
  final List<StorageLocation> locations;
  final BagPutawayPlan? bagPlan;
  final Object? suggestionError;
  final Object? confirmError;
  final Duration? delay;
  final BagPutawayPlan? Function()? onGetBagPlan;
  final List<PutawaySuggestion> Function()? onGetSuggestions;

  final List<int> startedReceipts = <int>[];
  final List<double> recordedQuantities = <double>[];
  int pendingCalls = 0;
  int locationCalls = 0;
  int suggestionCalls = 0;
  int bagPlanCalls = 0;
  int submitCalls = 0;
  int selectPutawayCalls = 0;
  int confirmReceiptCalls = 0;

  @override
  Future<List<InboundPutawayLine>> getPutawayPending() async {
    if (delay != null) await Future.delayed(delay!);
    pendingCalls++;
    return lines;
  }

  @override
  Future<List<StorageLocation>> getLocations() async {
    if (delay != null) await Future.delayed(delay!);
    locationCalls++;
    return locations;
  }

  @override
  Future<void> submit(int orderId) async {
    if (delay != null) await Future.delayed(delay!);
    submitCalls++;
  }

  @override
  Future<void> startReceipt(int orderId, int itemId) async {
    if (delay != null) await Future.delayed(delay!);
    startedReceipts.add(itemId);
  }

  @override
  Future<void> recordQuantity(
    int orderId,
    int itemId,
    double quantityReceived,
  ) async {
    if (delay != null) await Future.delayed(delay!);
    recordedQuantities.add(quantityReceived);
  }

  @override
  Future<List<PutawaySuggestion>> getPutawaySuggestions(
    int orderId,
    int itemId,
  ) async {
    if (delay != null) await Future.delayed(delay!);
    suggestionCalls++;
    if (onGetSuggestions != null) return onGetSuggestions!();
    if (suggestionError != null) throw suggestionError!;
    return suggestions;
  }

  @override
  Future<BagPutawayPlan?> getBagPutawayPlan(int orderId, int itemId) async {
    if (delay != null) await Future.delayed(delay!);
    bagPlanCalls++;
    if (onGetBagPlan != null) return onGetBagPlan!();
    return bagPlan;
  }

  @override
  Future<void> selectPutaway(
    int orderId,
    int itemId, {
    required int locationId,
    required bool isOverride,
    String? overrideReason,
    double? weightKg,
  }) async {
    if (delay != null) await Future.delayed(delay!);
    selectPutawayCalls++;
  }

  @override
  Future<void> confirmReceipt(
    int orderId,
    int itemId, {
    required String operationKey,
    List<BagPutawayColumn>? columns,
  }) async {
    if (delay != null) await Future.delayed(delay!);
    confirmReceiptCalls++;
    if (confirmError != null) throw confirmError!;
  }
}
