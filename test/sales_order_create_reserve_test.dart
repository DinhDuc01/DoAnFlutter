import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/sales_orders/data/sales_order_repository.dart';
import 'package:stocklite/features/sales_orders/models/sales_order.dart';
import 'package:stocklite/features/sales_orders/presentation/screens/sales_order_detail_screen.dart';

import 'support/fake_api_client.dart';

/// Mobile được duyệt đơn NEW khi session có quyền, sau đó kiểm tra & giữ hàng.
void main() {
  setUp(() => AuthSessionStore.current = _session());
  tearDown(() => AuthSessionStore.current = null);

  group('ApiSalesOrderRepository.create', () {
    test('gửi đúng payload và đọc mã đơn vừa tạo', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'isSucceeded': true,
          'resources': {
            'id': 12,
            'soCode': 'SO-20260814-0001',
            'totalAmount': 950000
          },
        },
      );

      final created = await ApiSalesOrderRepository(apiClient: client).create(
        CreateSalesOrderInput(
          customerId: 3,
          warehouseId: 1,
          channel: 'wholesale',
          expectedDeliveryDate: DateTime(2026, 8, 20),
          requiresMilling: true,
          depositAmount: 200000,
          shippingAddress: '  Long An  ',
          note: '   ',
          items: const [
            CreateSalesOrderLine(
              productVariantId: 5,
              quantityOrdered: 100,
              unitSalePrice: 10000,
              discountAmount: 50000,
            ),
          ],
        ),
      );

      expect(created.id, 12);
      expect(created.soCode, 'SO-20260814-0001');

      final call = client.calls.single;
      expect(call.path, '/api/v1/sales-orders');
      expect(call.body!['channel'], 'WHOLESALE');
      expect(call.body!['requiresMilling'], isTrue);
      expect(call.body!['shippingAddress'], 'Long An');
      // Ghi chú toàn khoảng trắng phải gửi null thay vì chuỗi rỗng.
      expect(call.body!['note'], isNull);
      final items = call.body!['items'] as List;
      expect(items.single['productVariantId'], 5);
      expect(items.single['discountAmount'], 50000);
    });

    test('chặn trùng sản phẩm trước khi gọi API', () async {
      final client = FakeApiClient();

      await expectLater(
        ApiSalesOrderRepository(apiClient: client).create(
          const CreateSalesOrderInput(
            customerId: 3,
            warehouseId: 1,
            channel: 'DIRECT',
            items: [
              CreateSalesOrderLine(
                productVariantId: 5,
                quantityOrdered: 10,
                unitSalePrice: 1000,
              ),
              CreateSalesOrderLine(
                productVariantId: 5,
                quantityOrdered: 20,
                unitSalePrice: 1000,
              ),
            ],
          ),
        ),
        throwsA(isA<SalesOrderException>()),
      );
      expect(client.calls, isEmpty);
    });

    test('chặn đơn không có dòng hàng', () async {
      final client = FakeApiClient();

      await expectLater(
        ApiSalesOrderRepository(apiClient: client).create(
          const CreateSalesOrderInput(
            customerId: 3,
            warehouseId: 1,
            channel: 'DIRECT',
            items: [],
          ),
        ),
        throwsA(isA<SalesOrderException>()),
      );
      expect(client.calls, isEmpty);
    });
  });

  group('ApiSalesOrderRepository.reserve', () {
    test('gọi đúng endpoint giữ hàng', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {'isSucceeded': true},
      );

      await ApiSalesOrderRepository(apiClient: client).reserve(9);

      expect(client.calls.single.path, '/api/v1/sales-orders/9/reserve');
    });

    test('đổi lỗi nghiệp vụ của backend thành SalesOrderException', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'isSucceeded': false,
          'message': 'Vượt hạn mức công nợ.',
        },
      );

      await expectLater(
        ApiSalesOrderRepository(apiClient: client).reserve(9),
        throwsA(
          isA<SalesOrderException>().having(
            (e) => e.message,
            'message',
            'Vượt hạn mức công nợ.',
          ),
        ),
      );
    });
  });

  group('ApiSalesOrderRepository.confirm', () {
    test('gọi đúng endpoint duyệt đơn bán', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {'isSucceeded': true},
      );

      await ApiSalesOrderRepository(apiClient: client).confirm(9);

      expect(client.calls.single.path, '/api/v1/sales-orders/9/confirm');
      expect(client.calls.single.method, 'POST');
    });

    test('không gọi API khi id không hợp lệ', () async {
      final client = FakeApiClient();

      await expectLater(
        ApiSalesOrderRepository(apiClient: client).confirm(0),
        throwsA(isA<SalesOrderException>()),
      );
      expect(client.calls, isEmpty);
    });
  });

  group('SalesOrderDetail — quyền thao tác trên mobile', () {
    test('chỉ đơn NEW đủ điều kiện duyệt', () {
      expect(_detail(SalesOrderStatusIds.newOrder).canConfirm, isTrue);
      expect(_detail(SalesOrderStatusIds.pendingConfirm).canConfirm, isFalse);
      expect(_detail(SalesOrderStatusIds.reserved).canConfirm, isFalse);
      expect(_detail(SalesOrderStatusIds.cancelled).canConfirm, isFalse);
    });

    test('chỉ giữ hàng được khi đơn đã ở Chờ xác nhận', () {
      expect(_detail(SalesOrderStatusIds.newOrder).canReserve, isFalse);
      expect(_detail(SalesOrderStatusIds.newOrder).waitingWebConfirm, isTrue);

      expect(_detail(SalesOrderStatusIds.pendingConfirm).canReserve, isTrue);
      expect(
        _detail(SalesOrderStatusIds.pendingConfirm).waitingWebConfirm,
        isFalse,
      );

      // Đã giữ hàng rồi thì không giữ lại.
      expect(_detail(SalesOrderStatusIds.reserved).canReserve, isFalse);
      expect(_detail(SalesOrderStatusIds.cancelled).canReserve, isFalse);
    });
    testWidgets('READ-only detail hides every sales mutation CTA',
        (tester) async {
      AuthSessionStore.current = _sessionWithActions({'READ'});
      final repository = _FakeDetailRepository(
        detail: _detail(SalesOrderStatusIds.newOrder),
      );
      await _pumpDetail(tester, repository);

      expect(find.byKey(const Key('sales_order_confirm')), findsNothing);
      expect(find.byKey(const Key('sales_order_reserve')), findsNothing);
      expect(find.byKey(const Key('sales_order_cancel')), findsNothing);
      expect(find.byKey(const Key('sales_order_create_outbound')), findsNothing);
      expect(repository.mutationCalls, 0);
    });

    testWidgets('UPDATE without APPROVE can confirm NEW exactly once',
        (tester) async {
      AuthSessionStore.current = _sessionWithActions({'READ', 'UPDATE'});
      final repository = _FakeDetailRepository(
        detail: _detail(SalesOrderStatusIds.newOrder),
      );
      await _pumpDetail(tester, repository);

      await tester.tap(find.byKey(const Key('sales_order_confirm')));
      await tester.pump();
      expect(repository.confirmCalls, 0);
      await tester.tap(find.byType(FilledButton).last);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.confirmCalls, 1);
    });

    testWidgets('UPDATE exposes only status-eligible actions', (tester) async {
      AuthSessionStore.current = _sessionWithActions({'READ', 'UPDATE'});

      var repository = _FakeDetailRepository(
        detail: _detail(SalesOrderStatusIds.pendingConfirm),
      );
      await _pumpDetail(tester, repository);
      expect(find.byKey(const Key('sales_order_reserve')), findsOneWidget);
      expect(find.byKey(const Key('sales_order_cancel')), findsOneWidget);
      expect(find.byKey(const Key('sales_order_confirm')), findsNothing);

      repository = _FakeDetailRepository(
        detail: _detail(SalesOrderStatusIds.reserved),
      );
      await _pumpDetail(tester, repository);
      expect(find.byKey(const Key('sales_order_create_outbound')), findsOneWidget);
      expect(find.byKey(const Key('sales_order_cancel')), findsOneWidget);

      for (final status in [
        SalesOrderStatusIds.completed,
        SalesOrderStatusIds.cancelled,
        0,
      ]) {
        repository = _FakeDetailRepository(detail: _detail(status));
        await _pumpDetail(tester, repository);
        expect(find.byKey(const Key('sales_order_confirm')), findsNothing);
        expect(find.byKey(const Key('sales_order_reserve')), findsNothing);
        expect(find.byKey(const Key('sales_order_cancel')), findsNothing);
        expect(
          find.byKey(const Key('sales_order_create_outbound')),
          findsNothing,
        );
      }
    });

    testWidgets('cancelling the cancel dialog does not call repository',
        (tester) async {
      AuthSessionStore.current = _sessionWithActions({'READ', 'UPDATE'});
      final repository = _FakeDetailRepository(
        detail: _detail(SalesOrderStatusIds.pendingConfirm),
      );
      await _pumpDetail(tester, repository);

      await tester.tap(find.byKey(const Key('sales_order_cancel')));
      await tester.pump();
      expect(repository.cancelCalls, 0);
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();
      expect(repository.cancelCalls, 0);
    });
  });
}

Future<void> _pumpDetail(
  WidgetTester tester,
  _FakeDetailRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SalesOrderDetailScreen(
        key: ValueKey(repository.detail.statusId),
        salesOrderId: repository.detail.id,
        repository: repository,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

AuthSession _sessionWithActions(Set<String> actions) => AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: AuthUser(
        id: 1,
        fullName: 'Sales',
        email: 'sales@example.com',
        permissions: [
          UserPermission(
            menuId: 1,
            menuCode: 'SALE_ORDERS',
            actions: actions,
          ),
        ],
      ),
    );

class _FakeDetailRepository implements SalesOrderRepository {
  _FakeDetailRepository({required this.detail});

  SalesOrderDetail detail;
  int confirmCalls = 0;
  int reserveCalls = 0;
  int cancelCalls = 0;
  int outboundCalls = 0;
  int getCalls = 0;
  int get mutationCalls =>
      confirmCalls + reserveCalls + cancelCalls + outboundCalls;

  @override
  Future<SalesOrderDetail> getById(int id) async {
    getCalls++;
    return detail;
  }

  @override
  Future<void> confirm(int id) async {
    confirmCalls++;
    detail = _detail(SalesOrderStatusIds.pendingConfirm);
  }

  @override
  Future<void> reserve(int id) async => reserveCalls++;

  @override
  Future<void> cancel(int id, {required String reason}) async => cancelCalls++;

  @override
  Future<int> createOutbound(int id, List<CreateOutboundLine> items) async {
    outboundCalls++;
    return 99;
  }

  @override
  Future<SalesOrderPage> getPaged({
    String? keyword,
    int? statusId,
    String? channel,
    int page = 1,
    int pageSize = 20,
  }) async => const SalesOrderPage(total: 0, items: []);

  @override
  Future<CreatedSalesOrder> create(CreateSalesOrderInput input) =>
      throw UnimplementedError();

  @override
  Future<List<SalesCustomerOption>> getCustomers() async => const [];

  @override
  Future<List<SalesWarehouseOption>> getWarehouses() async => const [];

  @override
  Future<List<SalesProductOption>> getProductVariants({String keyword = ''}) async =>
      const [];
}

SalesOrderDetail _detail(int statusId) => SalesOrderDetail.fromJson({
      'id': 1,
      'soCode': 'SO-01',
      'customerId': 2,
      'customerName': 'Khách A',
      'statusId': statusId,
      'statusName': salesOrderStatusLabel(statusId),
      'channel': 'DIRECT',
      'totalAmount': 1000,
      'remainingAmount': 1000,
      'items': const [],
      'outboundOrders': const [],
    });

AuthSession _session() => AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: AuthUser(id: 1, fullName: 'Tester', email: 'tester@example.com'),
    );
