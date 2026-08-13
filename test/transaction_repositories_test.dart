import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/api/api_client.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/giao_hang/data/api_giao_hang_repository.dart';
import 'package:stocklite/features/giao_hang/models/giao_hang_receipt.dart';
import 'package:stocklite/features/kho/data/api_kho_check_repository.dart';
import 'package:stocklite/features/kho/models/kho_check.dart';
import 'package:stocklite/features/products/data/product_variant_api.dart';
import 'package:stocklite/features/thu_mua/data/api_thu_mua_repository.dart';
import 'package:stocklite/features/thu_mua/models/thu_mua_receipt.dart';

import 'support/fake_api_client.dart';

void main() {
  setUp(() => AuthSessionStore.current = _session());
  tearDown(() => AuthSessionStore.current = null);

  group('ApiThuMuaRepository', () {
    test('builds draft from selected product without auto-selecting warehouse',
        () async {
      final repository = ApiThuMuaRepository(
        productVariantApi: _FakeProductApi(
          products: [_product(1, 'Gạo', onHand: 5, available: 5)],
        ),
        apiClient: FakeApiClient(),
      );

      final receipt = await repository.getDraftReceipt();

      expect(receipt.productVariantId, 1);
      expect(receipt.warehouseId, 0);
      expect(receipt.warehouseName, isEmpty);
      expect(receipt.currentStock, 5);
      expect(receipt.quantity, 1);
    });

    test('loads warehouses from API without fallback', () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {
          'resources': [
            {'id': 8, 'code': 'WH-8', 'name': 'Kho lúa'},
          ],
        },
      );
      final repository = ApiThuMuaRepository(apiClient: client);

      final warehouses = await repository.getWarehouses();

      expect(warehouses.single.id, 8);
      expect(warehouses.single.code, 'WH-8');
      expect(warehouses.single.name, 'Kho lúa');
      expect(client.calls.single.path, '/api/v1/warehouse');
    });

    test('warehouse API failure is surfaced without fallback', () async {
      final repository = ApiThuMuaRepository(
        productVariantApi: _FakeProductApi(
          products: [_product(1, 'Gạo', onHand: 5, available: 5)],
        ),
        apiClient: FakeApiClient(
          onGet: (_, __, ___) async =>
              throw const ApiException(message: 'forbidden'),
        ),
      );

      expect(
        repository.getWarehouses,
        throwsA(isA<ApiException>()),
      );
    });

    test('builds a draft for the product selected by the operator', () async {
      final selected = _product(2, 'Lúa thơm', onHand: 9, available: 9);
      final repository = ApiThuMuaRepository(
        productVariantApi: _FakeProductApi(
          products: [
            _product(1, 'Gạo', onHand: 5, available: 5),
            selected,
          ],
        ),
        apiClient: FakeApiClient(
          onGet: (_, __, ___) async => {
            'resources': [
              {'id': 8, 'name': 'Kho lúa'},
            ],
          },
        ),
      );

      final products = await repository.getSelectableProducts();
      final receipt = await repository.getDraftReceiptForProduct(selected);

      expect(products.map((item) => item.id), [1, 2]);
      expect(receipt.productVariantId, 2);
      expect(receipt.productName, 'Lúa thơm');
      expect(receipt.currentStock, 9);
    });

    test('requires login before confirming inbound', () async {
      AuthSessionStore.current = null;

      await expectLater(
        ApiThuMuaRepository(apiClient: FakeApiClient()).confirmInbound(
          receipt: _inboundReceipt(),
          quantity: 2,
          unitCostPrice: 10000,
          note: '',
        ),
        throwsA(isA<InboundApiException>()),
      );
    });

    test('loads unconfirmed receipts from the backend resources list',
        () async {
      final repository = ApiThuMuaRepository(
        apiClient: FakeApiClient(
          onGet: (path, _, __) async {
            expect(path, '/api/v1/paddy-purchase-receipts');
            return {
              'resources': [
                {
                  'id': 9,
                  'receiptCode': 'PPR-9',
                  'farmerName': 'Farmer',
                  'isConfirmed': false,
                  'actualWeightKg': 50,
                  'bagCount': 2,
                  'createdDate': '2026-08-08T10:00:00',
                },
                {
                  'id': 10,
                  'receiptCode': 'PPR-10',
                  'isConfirmed': true,
                },
              ],
            };
          },
        ),
      );

      final drafts = await repository.getDraftReceipts();

      expect(drafts.map((item) => item.id), [9]);
      expect(drafts.single.code, 'PPR-9');
      expect(drafts.single.bagCount, 2);
    });

    test('creates a draft paddy purchase receipt', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'isSucceeded': true,
          'resources': {'id': 21, 'receiptCode': 'PPR-20260804-0001'},
        },
      );

      final result =
          await ApiThuMuaRepository(apiClient: client).confirmInbound(
        receipt: _inboundReceipt().copyWith(
          bags: const [
            ThuMuaBag(sequenceNumber: 1, weightKg: 30),
            ThuMuaBag(sequenceNumber: 2, weightKg: 45),
          ],
        ),
        quantity: 3,
        unitCostPrice: 10000,
        note: '   ',
      );

      final call = client.calls.single;
      expect(call.path, '/api/v1/paddy-purchase-receipts');
      expect(call.body?['farmerId'], 4);
      expect(call.body?['warehouseId'], 2);
      expect(call.body?['bagCount'], 2);
      expect(call.body?['actualWeightKg'], 75);
      expect(call.body?.containsKey('bags'), isFalse);
      expect(call.body?['agreedPrice'], 10000);
      expect(call.body?['priceAdjustReason'], isNull);
      expect(result.id, 21);
      expect(result.code, 'PPR-20260804-0001');
      expect(result.status, 'Phiếu nháp');
    });

    test('updates an existing draft paddy purchase receipt', () async {
      final client = FakeApiClient(
        onPut: (_, __, ___) async => {
          'isSucceeded': true,
          'resources': {'id': 55, 'receiptCode': 'PPR-55'},
        },
      );

      final result =
          await ApiThuMuaRepository(apiClient: client).confirmInbound(
        receipt: _editReceipt().copyWith(
          bags: const [
            ThuMuaBag(sequenceNumber: 1, weightKg: 20),
            ThuMuaBag(sequenceNumber: 2, weightKg: 20),
            ThuMuaBag(sequenceNumber: 3, weightKg: 30),
            ThuMuaBag(sequenceNumber: 4, weightKg: 30),
          ],
        ),
        quantity: 4,
        unitCostPrice: 12000,
        note: '  cập nhật  ',
      );

      final call = client.calls.single;
      expect(call.method, 'PUT');
      expect(call.path, '/api/v1/paddy-purchase-receipts');
      expect(call.body?['id'], 55);
      expect(call.body?['warehouseId'], 2);
      expect(call.body?['bagCount'], 4);
      expect(call.body?['actualWeightKg'], 100);
      expect(call.body?.containsKey('bags'), isFalse);
      expect(call.body?['agreedPrice'], 12000);
      expect(call.body?['priceAdjustReason'], 'cập nhật');
      expect(result.id, 55);
      expect(result.code, 'PPR-55');
    });

    test('uses trimmed note and backend failure message', () async {
      final successClient = FakeApiClient(
        onPost: (_, __, ___) async => {'isSucceeded': true},
      );
      await ApiThuMuaRepository(apiClient: successClient).confirmInbound(
        receipt: _inboundReceipt(),
        quantity: 1,
        unitCostPrice: 10000,
        note: '  Lúa mới  ',
      );
      expect(
        successClient.calls.first.body?['priceAdjustReason'],
        'Lúa mới',
      );

      final failureClient = FakeApiClient(
        onPost: (_, __, ___) async => {
          'isSucceeded': false,
          'message': 'Không đủ quyền',
        },
      );
      await expectLater(
        ApiThuMuaRepository(apiClient: failureClient).confirmInbound(
          receipt: _inboundReceipt(),
          quantity: 1,
          unitCostPrice: 10000,
          note: '',
        ),
        throwsA(
          isA<InboundApiException>().having(
            (error) => error.message,
            'message',
            'Không đủ quyền',
          ),
        ),
      );
    });
  });

  group('ApiGiaoHangRepository', () {
    test('creates one receipt per usable warehouse and sorts stock descending',
        () async {
      final products = [
        _product(
          1,
          'Gạo',
          onHand: 20,
          available: 20,
          warehouses: const [
            WarehouseInventory(
              inventoryId: 1,
              warehouseId: 1,
              warehouseName: 'Kho A',
              quantityOnHand: 4,
              quantityReserved: 0,
              quantityAvailable: 4,
            ),
            WarehouseInventory(
              inventoryId: 2,
              warehouseId: 2,
              warehouseName: 'Kho B',
              quantityOnHand: 12,
              quantityReserved: 0,
              quantityAvailable: 12,
            ),
            WarehouseInventory(
              inventoryId: 3,
              warehouseId: 0,
              warehouseName: 'Invalid',
              quantityOnHand: 10,
              quantityReserved: 0,
              quantityAvailable: 10,
            ),
          ],
        ),
      ];
      final repository = ApiGiaoHangRepository(
        productVariantApi: _FakeProductApi(products: products),
      );

      final receipts = await repository.getAvailableReceipts();

      expect(receipts, hasLength(2));
      expect(receipts.map((item) => item.currentStock), [12, 4]);
      expect(receipts.first.warehouseName, 'Kho B');
    });

    test('draft rejects an empty available receipt list', () async {
      final repository = ApiGiaoHangRepository(
        productVariantApi: _FakeProductApi(products: const []),
      );

      await expectLater(
        repository.getDraftReceipt(),
        throwsA(isA<GiaoHangApiException>()),
      );
    });

    test('loads active customers and removes invalid ids', () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {
          'resources': [
            {'id': 1, 'code': 'A', 'name': 'Khách A', 'isActive': true},
            {'id': 2, 'code': 'B', 'name': 'Khách B', 'isActive': false},
            {'id': 0, 'code': 'C', 'name': 'Invalid'},
            {'id': 3, 'code': 'D'},
          ],
        },
      );

      final customers =
          await ApiGiaoHangRepository(apiClient: client).getCustomers();

      expect(customers.map((item) => item.id), [1, 3]);
      expect(customers.last.name, 'Khách hàng');
    });

    test('requires login before loading customers', () async {
      AuthSessionStore.current = null;

      await expectLater(
        ApiGiaoHangRepository(apiClient: FakeApiClient()).getCustomers(),
        throwsA(isA<GiaoHangApiException>()),
      );
    });

    test('requires customer before outbound confirmation', () async {
      await expectLater(
        ApiGiaoHangRepository(apiClient: FakeApiClient()).confirmOutbound(
          receipt: _deliveryReceipt(),
          quantity: 2,
          unitSalePrice: 15000,
          expectedDeliveryDate: DateTime(2026, 7, 30),
          shippingAddress: 'Cần Thơ',
          note: '',
        ),
        throwsA(isA<GiaoHangApiException>()),
      );
    });

    test('creates a delivery sales order with customer and trimmed note',
        () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'isSucceeded': true,
          'resources': {'id': 31, 'soCode': 'SO-31'},
        },
      );
      final receipt = _deliveryReceipt().copyWith(
        customer: const GiaoHangCustomer(
          id: 1,
          code: 'KH',
          name: 'Khách A',
        ),
      );

      final result =
          await ApiGiaoHangRepository(apiClient: client).confirmOutbound(
        receipt: receipt,
        quantity: 4,
        unitSalePrice: 15000,
        expectedDeliveryDate: DateTime(2026, 7, 30),
        shippingAddress: ' Cổng sau ',
        note: '  Giao cổng sau  ',
      );

      expect(client.calls.single.path, '/api/v1/sales-orders');
      final body = client.calls.single.body!;
      expect(body['customerId'], 1);
      expect(body['warehouseId'], 2);
      expect(body['channel'], 'WHOLESALE');
      expect(body['shippingAddress'], 'Cổng sau');
      expect(body['note'], 'Giao cổng sau');
      final item = (body['items'] as List).single as Map<String, dynamic>;
      expect(item['quantityOrdered'], 4);
      expect(item['unitSalePrice'], 15000);
      expect(result.id, 31);
      expect(result.code, 'SO-31');
    });

    test('uses backend failure message for outbound adjustment', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'isSucceeded': false,
          'message': 'Tồn kho không đủ',
        },
      );
      final receipt = _deliveryReceipt().copyWith(
        customer: const GiaoHangCustomer(
          id: 1,
          code: 'KH',
          name: 'Khách A',
        ),
      );

      await expectLater(
        ApiGiaoHangRepository(apiClient: client).confirmOutbound(
          receipt: receipt,
          quantity: 99,
          unitSalePrice: 15000,
          expectedDeliveryDate: DateTime(2026, 7, 30),
          shippingAddress: 'Cần Thơ',
          note: '',
        ),
        throwsA(
          isA<GiaoHangApiException>().having(
            (error) => error.message,
            'message',
            'Tồn kho không đủ',
          ),
        ),
      );
    });
  });

  group('ApiKhoCheckRepository', () {
    test('selects warehouse with highest on-hand total', () async {
      final products = [
        _product(
          1,
          'Gạo',
          onHand: 20,
          available: 20,
          warehouses: const [
            WarehouseInventory(
              inventoryId: 1,
              warehouseId: 1,
              warehouseName: 'Kho A',
              quantityOnHand: 10,
              quantityReserved: 0,
              quantityAvailable: 10,
            ),
            WarehouseInventory(
              inventoryId: 2,
              warehouseId: 2,
              warehouseName: 'Kho B',
              quantityOnHand: 8,
              quantityReserved: 0,
              quantityAvailable: 8,
            ),
          ],
        ),
        _product(
          2,
          'Cám',
          onHand: 7,
          available: 7,
          warehouses: const [
            WarehouseInventory(
              inventoryId: 3,
              warehouseId: 2,
              warehouseName: 'Kho B',
              quantityOnHand: 7,
              quantityReserved: 0,
              quantityAvailable: 7,
            ),
          ],
        ),
      ];

      final check = await ApiKhoCheckRepository(
        productVariantApi: _FakeProductApi(products: products),
      ).getDraftCheck();

      expect(check.warehouseId, 2);
      expect(check.warehouseName, 'Kho B');
      expect(check.items, hasLength(2));
      expect(check.totalSystemQuantity, 15);
    });

    test('rejects draft when no positive on-hand inventory exists', () async {
      final repository = ApiKhoCheckRepository(
        productVariantApi: _FakeProductApi(
          products: [
            _product(1, 'Gạo', onHand: 0, available: 0),
          ],
        ),
      );

      await expectLater(
        repository.getDraftCheck(),
        throwsA(isA<KhoCheckException>()),
      );
    });

    test('requires login before creating stocktake', () async {
      AuthSessionStore.current = null;

      await expectLater(
        ApiKhoCheckRepository(apiClient: FakeApiClient()).createStockTake(
          check: _stockCheck(),
          items: _stockCheck().items,
        ),
        throwsA(isA<KhoCheckException>()),
      );
    });

    test('loads the existing backend stocktake draft', () async {
      final repository = ApiKhoCheckRepository(
        productVariantApi: _FakeProductApi(
          products: [_product(1, 'Gạo', onHand: 12, available: 12)],
        ),
        apiClient: FakeApiClient(
          onGet: (_, __, ___) async => {
            'resources': [
              {
                'id': 10,
                'warehouseId': 1,
                'stockTakeStatusId': 1,
                'stCode': 'ST-DRAFT-10',
                'createdDate': '2026-08-09T08:00:00',
                'stockTakeItems': [
                  {
                    'id': 8,
                    'productVariantId': 1,
                    'locationId': 3,
                    'systemQuantity': 12,
                    'actualQuantity': 11,
                  },
                ],
              },
            ],
          },
        ),
      );

      final check = await repository.getDraftCheck();

      expect(check.id, 10);
      expect(check.statusId, 1);
      expect(check.items.single.id, 8);
      expect(check.items.single.actualQuantity, 11);
    });

    test('submits a stocktake draft with status Submitted', () async {
      final client = FakeApiClient(
        onPut: (_, __, ___) async => {'isSucceeded': true},
      );
      final check = _stockCheck();

      await ApiKhoCheckRepository(apiClient: client).submitStockTake(
        stockTakeId: 77,
        check: check,
        items: check.items,
        note: '  Đã kiểm đủ  ',
      );

      final call = client.calls.single;
      expect(call.method, 'PUT');
      expect(call.path, '/api/v1/stocktake');
      expect(call.body?['id'], 77);
      expect(call.body?['stockTakeStatusId'], 2);
      expect(call.body?['note'], 'Đã kiểm đủ');
    });

    test('posts stocktake items and parses map id', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'resources': {'id': '77'},
        },
      );
      final check = _stockCheck();

      final id = await ApiKhoCheckRepository(apiClient: client).createStockTake(
        check: check,
        items: check.items,
        note: '  Đếm cuối ngày  ',
      );

      expect(id, 77);
      final body = client.calls.single.body!;
      expect(body['warehouseId'], 1);
      expect(body['note'], 'Đếm cuối ngày');
      final items = body['stockTakeItems'] as List<dynamic>;
      expect(items.single['actualQuantity'], 12);
      expect(items.single['qrScanned'], isFalse);
    });

    test('parses numeric resource id and converts API errors', () async {
      final numberClient = FakeApiClient(
        onPost: (_, __, ___) async => {'resources': 8.0},
      );
      expect(
        await ApiKhoCheckRepository(apiClient: numberClient).createStockTake(
          check: _stockCheck(),
          items: _stockCheck().items,
        ),
        8,
      );

      final errorClient = FakeApiClient(
        onPost: (_, __, ___) async =>
            throw const ApiException(message: 'Stocktake failed'),
      );
      await expectLater(
        ApiKhoCheckRepository(apiClient: errorClient).createStockTake(
          check: _stockCheck(),
          items: _stockCheck().items,
        ),
        throwsA(
          isA<KhoCheckException>().having(
            (error) => error.message,
            'message',
            'Stocktake failed',
          ),
        ),
      );
    });
  });
}

class _FakeProductApi extends ProductVariantApi {
  _FakeProductApi({required this.products});

  final List<ProductVariantStock> products;

  @override
  Future<List<ProductVariantStock>> activeVariantsWithStock() async =>
      List.of(products);

  @override
  Future<ProductVariantStock> firstVariantForThuMua() async {
    if (products.isEmpty) {
      throw const ProductVariantApiException('No product');
    }
    return products.first;
  }
}

ProductVariantStock _product(
  int id,
  String name, {
  required int onHand,
  required int available,
  List<WarehouseInventory> warehouses = const [],
}) {
  return ProductVariantStock(
    id: id,
    name: name,
    sku: 'SKU-$id',
    weightKg: 25,
    quantityOnHand: onHand,
    quantityReserved: onHand - available,
    quantityAvailable: available,
    warehouses: warehouses,
  );
}

ThuMuaReceipt _inboundReceipt() {
  return ThuMuaReceipt(
    productVariantId: 1,
    warehouseId: 2,
    warehouseName: 'Kho A',
    status: 'Nhập kho',
    productName: 'Gạo',
    sku: 'GAO',
    currentStock: 5,
    receiptCode: 'PN-01',
    weightKg: 25,
    quantity: 1,
    noteHint: '',
    unitCostPrice: 10000,
    supplier: const ThuMuaSupplier(
      id: 4,
      code: 'SUP-04',
      name: 'Nhà cung cấp A',
    ),
    expectedDate: DateTime(2026, 7, 30),
  );
}

ThuMuaReceipt _editReceipt() {
  return ThuMuaReceipt(
    id: 55,
    productVariantId: 1,
    warehouseId: 2,
    warehouseName: 'Kho A',
    status: 'Phiếu nháp',
    productName: 'Gạo',
    sku: 'GAO',
    currentStock: 5,
    receiptCode: 'PPR-55',
    weightKg: 25,
    quantity: 1,
    noteHint: '',
    unitCostPrice: 10000,
    supplier: const ThuMuaSupplier(
      id: 4,
      code: 'SUP-04',
      name: 'Nhà cung cấp A',
    ),
    expectedDate: DateTime(2026, 7, 30),
    actualWeightKg: 100,
    paidAmount: 1000,
  );
}

GiaoHangReceipt _deliveryReceipt() {
  return GiaoHangReceipt(
    productVariantId: 1,
    warehouseId: 2,
    warehouseName: 'Kho A',
    locationId: 3,
    status: 'Sẵn sàng giao',
    productName: 'Gạo',
    sku: 'GAO',
    currentStock: 10,
    receiptCode: 'GH-01',
    quantity: 1,
    noteHint: '',
    unitSalePrice: 15000,
    expectedDeliveryDate: DateTime(2026, 7, 30),
    shippingAddress: 'Cần Thơ',
  );
}

KhoCheck _stockCheck() {
  return KhoCheck(
    warehouseId: 1,
    checkCode: 'ST-01',
    warehouseName: 'Kho A',
    noteHint: '',
    checkedAt: DateTime(2026),
    items: const [
      KhoCheckItem(
        productVariantId: 1,
        productName: 'Gạo',
        sku: 'GAO',
        systemQuantity: 10,
        actualQuantity: 12,
        locationId: 3,
      ),
    ],
  );
}

AuthSession _session() {
  return const AuthSession(
    accessToken: 'token',
    refreshToken: 'refresh',
    user: AuthUser(id: 1, fullName: 'Tester', email: 'tester@example.com'),
  );
}
