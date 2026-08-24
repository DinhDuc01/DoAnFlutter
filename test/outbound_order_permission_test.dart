import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/outbound_orders/data/outbound_order_repository.dart';
import 'package:stocklite/features/outbound_orders/models/outbound_order.dart';
import 'package:stocklite/features/outbound_orders/presentation/screens/outbound_order_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AuthSessionStore.current = null);

  group('Outbound order permission and CTA status guard', () {
    testWidgets('READ-only user sees no mutation CTAs on detail screen',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ'});
      final repository =
          _FakeOutboundRepository(_order(statusId: OutboundStatusIds.draft));

      await _pumpDetail(tester, repository);

      expect(find.byKey(const Key('outbound_allocate')), findsNothing);
      expect(find.byKey(const Key('outbound_pick')), findsNothing);
      expect(find.byKey(const Key('outbound_pack')), findsNothing);
      expect(find.byKey(const Key('outbound_dispatch')), findsNothing);
      expect(find.byKey(const Key('outbound_complete_delivery')), findsNothing);
      expect(find.byKey(const Key('outbound_fail_delivery')), findsNothing);
      expect(find.byKey(const Key('outbound_cancel')), findsNothing);
      expect(repository.allocateCalls, 0);
      expect(repository.cancelCalls, 0);
    });

    testWidgets('UPDATE shows allocate and cancel for DRAFT status',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
      final repository =
          _FakeOutboundRepository(_order(statusId: OutboundStatusIds.draft));

      await _pumpDetail(tester, repository);

      expect(find.byKey(const Key('outbound_allocate')), findsOneWidget);
      expect(find.byKey(const Key('outbound_cancel')), findsOneWidget);
      expect(find.byKey(const Key('outbound_pick')), findsNothing);
      expect(find.byKey(const Key('outbound_pack')), findsNothing);
      expect(find.byKey(const Key('outbound_dispatch')), findsNothing);
      expect(find.byKey(const Key('outbound_complete_delivery')), findsNothing);
      expect(find.byKey(const Key('outbound_fail_delivery')), findsNothing);
    });

    testWidgets('UPDATE shows pick before all items are picked',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
      final repository = _FakeOutboundRepository(
        _order(statusId: OutboundStatusIds.picking, quantityPicked: 0),
      );

      await _pumpDetail(tester, repository);

      expect(find.byKey(const Key('outbound_pick')), findsOneWidget);
      expect(find.byKey(const Key('outbound_pack')), findsNothing);
      expect(find.byKey(const Key('outbound_cancel')), findsOneWidget);
      expect(find.byKey(const Key('outbound_allocate')), findsNothing);
      expect(find.byKey(const Key('outbound_dispatch')), findsNothing);
      expect(find.byKey(const Key('outbound_complete_delivery')), findsNothing);
      expect(find.byKey(const Key('outbound_fail_delivery')), findsNothing);
    });

    testWidgets('UPDATE shows pack only after all items are picked',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
      final repository = _FakeOutboundRepository(
        _order(statusId: OutboundStatusIds.picking, quantityPicked: 1000),
      );

      await _pumpDetail(tester, repository);

      expect(find.byKey(const Key('outbound_pick')), findsNothing);
      expect(find.byKey(const Key('outbound_pack')), findsOneWidget);
      expect(find.byKey(const Key('outbound_cancel')), findsOneWidget);
    });

    testWidgets('UPDATE shows dispatch and cancel for PACKED status',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
      final repository =
          _FakeOutboundRepository(_order(statusId: OutboundStatusIds.packed));

      await _pumpDetail(tester, repository);

      expect(find.byKey(const Key('outbound_dispatch')), findsOneWidget);
      expect(find.byKey(const Key('outbound_cancel')), findsOneWidget);
      expect(find.byKey(const Key('outbound_allocate')), findsNothing);
      expect(find.byKey(const Key('outbound_pick')), findsNothing);
      expect(find.byKey(const Key('outbound_pack')), findsNothing);
      expect(find.byKey(const Key('outbound_complete_delivery')), findsNothing);
      expect(find.byKey(const Key('outbound_fail_delivery')), findsNothing);
    });

    testWidgets(
        'UPDATE shows complete-delivery and fail-delivery for DISPATCHED status',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
      final repository = _FakeOutboundRepository(
          _order(statusId: OutboundStatusIds.dispatched));

      await _pumpDetail(tester, repository);

      expect(
          find.byKey(const Key('outbound_complete_delivery')), findsOneWidget);
      expect(find.byKey(const Key('outbound_fail_delivery')), findsOneWidget);
      expect(find.byKey(const Key('outbound_allocate')), findsNothing);
      expect(find.byKey(const Key('outbound_pick')), findsNothing);
      expect(find.byKey(const Key('outbound_pack')), findsNothing);
      expect(find.byKey(const Key('outbound_dispatch')), findsNothing);
      expect(find.byKey(const Key('outbound_cancel')), findsNothing);
    });

    for (final status in <int>[
      OutboundStatusIds.completed,
      OutboundStatusIds.cancelled,
      OutboundStatusIds.deliveryFailed,
      0,
      999,
    ]) {
      testWidgets('status $status is read-only even with UPDATE permission',
          (tester) async {
        AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
        final repository = _FakeOutboundRepository(_order(statusId: status));

        await _pumpDetail(tester, repository);

        expect(find.byKey(const Key('outbound_allocate')), findsNothing);
        expect(find.byKey(const Key('outbound_pick')), findsNothing);
        expect(find.byKey(const Key('outbound_pack')), findsNothing);
        expect(find.byKey(const Key('outbound_dispatch')), findsNothing);
        expect(
            find.byKey(const Key('outbound_complete_delivery')), findsNothing);
        expect(find.byKey(const Key('outbound_fail_delivery')), findsNothing);
        expect(find.byKey(const Key('outbound_cancel')), findsNothing);
      });
    }

    testWidgets('COMPLETED hides live scale and shows recorded outbound result',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
      final repository = _FakeOutboundRepository(
        _order(statusId: OutboundStatusIds.completed),
      );

      await _pumpDetail(tester, repository);

      expect(find.byKey(const Key('outbound_scale_status')), findsNothing);
      expect(find.text('Kết quả xuất kho'), findsOneWidget);
      expect(find.text('Cân & đóng bao'), findsNothing);
      expect(find.text('Đã xuất'), findsOneWidget);
      expect(find.byKey(const Key('outbound_progress_steps')), findsOneWidget);
      expect(find.text('Tiến trình xử lý'), findsOneWidget);
      for (final label in const [
        'Phân bổ lô',
        'Lấy hàng',
        'Đóng gói',
        'Xuất kho',
        'Giao hàng',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('PICKING hides header scale connection and keeps weighing summary',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
      final repository = _FakeOutboundRepository(
        _order(statusId: OutboundStatusIds.picking),
      );

      await _pumpDetail(tester, repository);

      expect(find.byKey(const Key('outbound_scale_status')), findsNothing);
      expect(find.text('Cân & đóng bao'), findsOneWidget);
      expect(find.text('Thực lấy'), findsOneWidget);
      expect(find.text('Kết quả xuất kho'), findsNothing);
    });

    testWidgets('cancelling dialog does not invoke cancel API', (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
      final repository =
          _FakeOutboundRepository(_order(statusId: OutboundStatusIds.draft));
      await _pumpDetail(tester, repository);

      await tester.tap(find.byKey(const Key('outbound_cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repository.cancelCalls, 0);

      await tester.tap(find.byKey(const Key('reason_cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.cancelCalls, 0);
    });

    testWidgets('confirming cancel calls repository once and reloads detail',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
      final repository =
          _FakeOutboundRepository(_order(statusId: OutboundStatusIds.draft));
      await _pumpDetail(tester, repository);

      await tester.tap(find.byKey(const Key('outbound_cancel')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'Khách đổi kế hoạch giao hàng');
      await tester.tap(find.byKey(const Key('reason_confirm')));
      await tester.pumpAndSettle();

      expect(repository.cancelCalls, 1);
      expect(repository.lastCancelReason, 'Khách đổi kế hoạch giao hàng');
      expect(repository.getByIdCalls, greaterThanOrEqualTo(2));
    });
  });
}

Future<void> _pumpDetail(
  WidgetTester tester,
  _FakeOutboundRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OutboundOrderDetailScreen(
        outboundOrderId: repository.detail.id,
        preview: repository.detail,
        repository: repository,
      ),
    ),
  );
  await tester.pump();
}

AuthSession _session(Set<String> actions) {
  return AuthSession(
    accessToken: 'test-token',
    refreshToken: 'test-refresh',
    user: AuthUser(
      id: 1,
      fullName: 'Kho Quản lý',
      email: 'kho@example.com',
      roles: const [UserRole(id: 2, code: 'WAREHOUSE', name: 'Kho')],
      menus: const [
        UserMenu(id: 10, code: 'OUTBOUND_ORDERS', name: 'Phiếu xuất kho')
      ],
      permissions: [
        UserPermission(
          menuId: 10,
          menuCode: 'OUTBOUND_ORDERS',
          actions: actions,
        ),
      ],
    ),
  );
}

OutboundOrderDetail _order({
  required int statusId,
  double quantityPicked = 1000,
}) {
  return OutboundOrderDetail(
    id: 101,
    salesOrderId: 55,
    soCode: 'SO-2026-0055',
    customerId: 9,
    customerName: 'Đại lý Lúa Vàng',
    statusId: statusId,
    statusName: outboundStatusLabel(statusId),
    statusCode: 'STATUS_$statusId',
    warehouseId: 1,
    warehouseName: 'Kho Tổng',
    totalDispatchedValue: 50000000,
    totalDispatchedSaleValue: 60000000,
    items: [
      OutboundOrderItem(
        id: 1,
        productVariantId: 10,
        productVariantName: 'Gạo ST25 Đóng Túi 5kg',
        quantityOrdered: 1000,
        quantityPicked: quantityPicked,
        unitCostPrice: 20000,
        allocations: [],
        allocationGroups: [],
      ),
    ],
  );
}

class _FakeOutboundRepository implements OutboundOrderRepository {
  _FakeOutboundRepository(this.detail);

  OutboundOrderDetail detail;
  int getByIdCalls = 0;
  int allocateCalls = 0;
  int pickCalls = 0;
  int confirmPackingCalls = 0;
  int confirmDispatchCalls = 0;
  int completeDeliveryCalls = 0;
  int failDeliveryCalls = 0;
  int cancelCalls = 0;
  String? lastCancelReason;

  @override
  Future<OutboundOrderDetail> getById(int id) async {
    getByIdCalls++;
    return detail;
  }

  @override
  Future<OutboundOrderPage> getPaged({
    String? keyword,
    int? statusId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const OutboundOrderPage(total: 1, items: []);
  }

  @override
  Future<List<OutboundAllocationCandidate>> getAllocationCandidates(
      int id) async {
    return const [];
  }

  @override
  Future<void> allocate(int id, List<AllocateItemPayload> allocations) async {
    allocateCalls++;
  }

  @override
  Future<void> pick(int id, List<PickAllocationPayload> picks) async {
    pickCalls++;
  }

  @override
  Future<void> confirmPacking(
    int id, {
    String? qrCode,
    double? actualWeightKg,
    String? scaleDevice,
    List<PackingItemWeightPayload> items = const [],
  }) async {
    confirmPackingCalls++;
  }

  @override
  Future<void> confirmDispatch(int id,
      {DateTime? dueDate, String? note}) async {
    confirmDispatchCalls++;
  }

  @override
  Future<CompleteDeliveryResult> completeDelivery(
    int id, {
    required String receiverName,
    required double paymentAmount,
    String? deliveryNote,
    String? proofImageUrl,
  }) async {
    completeDeliveryCalls++;
    return CompleteDeliveryResult(paymentAmount: paymentAmount);
  }

  @override
  Future<void> failDelivery(int id, {required String reason}) async {
    failDeliveryCalls++;
  }

  @override
  Future<void> cancel(int id, {required String reason}) async {
    cancelCalls++;
    lastCancelReason = reason;
  }

  @override
  Future<OutboundDebtSnapshot?> getReceivableSnapshot({
    required int outboundOrderId,
    required String soCode,
  }) async {
    return null;
  }
}
