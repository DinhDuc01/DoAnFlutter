import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/sales_orders/data/sales_order_repository.dart';
import 'package:stocklite/features/sales_orders/models/sales_order.dart';

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
  });
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
