import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/api/api_client.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/products/data/product_variant_api.dart';

import 'support/fake_api_client.dart';

void main() {
  setUp(() => AuthSessionStore.current = _session());
  tearDown(() => AuthSessionStore.current = null);

  test('requires login before loading active variants', () async {
    AuthSessionStore.current = null;

    await expectLater(
      ProductVariantApi(apiClient: FakeApiClient()).activeVariantsWithStock(),
      throwsA(isA<ProductVariantApiException>()),
    );
  });

  test('loads valid variants, combines stock and sorts by name', () async {
    final client = FakeApiClient(
      onGet: (path, query, token) async {
        if (path == '/api/v1/product-variant/search') {
          expect(query, {
            'pageIndex': '1',
            'pageSize': '25',
            'isActive': 'true',
          });
          return {
            'resources': {
              'dataSource': [
                {'id': 2, 'sku': 'B', 'name': 'Cám'},
                {'id': 0, 'sku': 'INVALID', 'name': 'Invalid'},
                {'id': 1, 'sku': 'A', 'name': 'Gạo'},
                {'id': 3, 'sku': ' ', 'name': 'No SKU'},
              ],
            },
          };
        }
        final id = path.endsWith('/1') ? 1 : 2;
        return {
          'resources': [
            {
              'id': id * 10,
              'warehouseId': id,
              'warehouseName': 'Kho $id',
              'quantityOnHand': id * 10,
              'quantityReserved': id,
            },
          ],
        };
      },
    );

    final products = await ProductVariantApi(apiClient: client, pageSize: 25)
        .activeVariantsWithStock();

    expect(products.map((product) => product.name), ['Cám', 'Gạo']);
    expect(products.first.quantityAvailable, 18);
    expect(products.last.quantityAvailable, 9);
    expect(products, hasLength(2));
  });

  test('falls back to SKU stock endpoint when inventory endpoint fails',
      () async {
    final client = FakeApiClient(
      onGet: (path, query, token) async {
        if (path.endsWith('/search')) {
          return {
            'resources': {
              'dataSource': [
                {'id': 1, 'sku': 'GAO', 'name': 'Gạo'},
              ],
            },
          };
        }
        if (path.contains('by-variant')) {
          throw const ApiException(message: 'inventory unavailable');
        }
        expect(query, {'sku': 'GAO'});
        return {
          'resources': {
            'quantityOnHand': 8,
            'quantityReserved': 3,
            'warehouseId': 1,
          },
        };
      },
    );

    final product =
        (await ProductVariantApi(apiClient: client).activeVariantsWithStock())
            .single;

    expect(product.quantityAvailable, 5);
    expect(
      client.calls.map((call) => call.path),
      contains('/api/v1/product-variant/check-sku'),
    );
  });

  test('rejects invalid variant detail id without API call', () async {
    final client = FakeApiClient();

    await expectLater(
      ProductVariantApi(apiClient: client).variantDetails(0),
      throwsA(isA<ProductVariantApiException>()),
    );
    expect(client.calls, isEmpty);
  });

  test('loads variant details and inventory list', () async {
    final client = FakeApiClient(
      onGet: (path, query, token) async {
        if (path == '/api/v1/product-variant/7') {
          return {
            'resources': {'id': 7, 'sku': 'GAO', 'name': 'Gạo thơm'},
          };
        }
        return {
          'resources': [
            {
              'warehouseId': 1,
              'warehouseName': 'Kho A',
              'quantityOnHand': 12,
              'quantityReserved': 2,
            },
          ],
        };
      },
    );

    final product =
        await ProductVariantApi(apiClient: client).variantDetails(7);

    expect(product.id, 7);
    expect(product.name, 'Gạo thơm');
    expect(product.quantityAvailable, 10);
    expect(product.warehouses.single.warehouseName, 'Kho A');
  });

  test('rejects detail response without product resources', () async {
    final client = FakeApiClient(
      onGet: (_, __, ___) async => const {},
    );

    await expectLater(
      ProductVariantApi(apiClient: client).variantDetails(7),
      throwsA(isA<ProductVariantApiException>()),
    );
  });

  test('first inbound variant chooses the lowest available stock', () async {
    final api = _ProductListApi([
      _product(1, 'B', available: 10),
      _product(2, 'A', available: 3),
      _product(3, 'C', available: 3),
    ]);

    final product = await api.firstVariantForThuMua();

    expect(product.id, 2);
  });

  test('first outbound variant chooses highest positive stock', () async {
    final api = _ProductListApi([
      _product(1, 'A', available: 0),
      _product(2, 'B', available: 8),
      _product(3, 'C', available: 15),
    ]);

    final product = await api.firstVariantForGiaoHang();

    expect(product.id, 3);
  });

  test('first inbound and outbound variants reject empty usable lists',
      () async {
    await expectLater(
      _ProductListApi(const []).firstVariantForThuMua(),
      throwsA(isA<ProductVariantApiException>()),
    );
    await expectLater(
      _ProductListApi([
        _product(1, 'A', available: 0),
      ]).firstVariantForGiaoHang(),
      throwsA(isA<ProductVariantApiException>()),
    );
  });

  test('limits concurrent inventory requests', () async {
    var activeRequests = 0;
    var peakRequests = 0;
    final client = FakeApiClient(
      onGet: (path, query, token) async {
        if (path.endsWith('/search')) {
          return {
            'resources': {
              'dataSource': [
                for (var id = 1; id <= 9; id++)
                  {'id': id, 'sku': 'SKU-$id', 'name': 'Product $id'},
              ],
            },
          };
        }

        activeRequests++;
        if (activeRequests > peakRequests) peakRequests = activeRequests;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        activeRequests--;
        return {
          'resources': [
            {
              'warehouseId': 1,
              'quantityOnHand': 1,
              'quantityReserved': 0,
            },
          ],
        };
      },
    );

    final products = await ProductVariantApi(
      apiClient: client,
      maxConcurrentStockRequests: 3,
    ).activeVariantsWithStock();

    expect(products, hasLength(9));
    expect(peakRequests, lessThanOrEqualTo(3));
  });
}

class _ProductListApi extends ProductVariantApi {
  _ProductListApi(this.products);

  final List<ProductVariantStock> products;

  @override
  Future<List<ProductVariantStock>> activeVariantsWithStock() async =>
      List.of(products);
}

ProductVariantStock _product(int id, String name, {required int available}) {
  return ProductVariantStock(
    id: id,
    name: name,
    sku: 'SKU-$id',
    weightKg: 1,
    quantityOnHand: available,
    quantityReserved: 0,
    quantityAvailable: available,
  );
}

AuthSession _session() {
  return const AuthSession(
    accessToken: 'token',
    refreshToken: 'refresh',
    user: AuthUser(id: 1, fullName: 'Tester', email: 'tester@example.com'),
  );
}
