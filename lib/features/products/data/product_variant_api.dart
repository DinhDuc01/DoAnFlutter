import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';

/// Gọi các API sản phẩm, biến thể sản phẩm và tồn kho.
class ProductVariantApi {
  ProductVariantApi({
    ApiClient? apiClient,
    this.pageSize = 50,
    this.maxConcurrentStockRequests = 8,
  }) : _apiClient =
            apiClient ?? ApiClient(requestTimeout: const Duration(seconds: 15));

  final ApiClient _apiClient;
  final int pageSize;
  final int maxConcurrentStockRequests;

  /// Lấy danh sách biến thể đang hoạt động kèm tồn kho thực tế.
  Future<List<ProductVariantStock>> activeVariantsWithStock() async {
    final token = _currentToken();
    final List<Map<String, dynamic>> variants;
    try {
      variants = await _loadActiveVariants(token);
    } on ApiException catch (error) {
      throw ProductVariantApiException(error.message);
    }

    final products = <ProductVariantStock>[];
    final concurrency =
        maxConcurrentStockRequests < 1 ? 1 : maxConcurrentStockRequests;
    for (var start = 0; start < variants.length; start += concurrency) {
      final end = (start + concurrency).clamp(0, variants.length);
      final batch = variants.sublist(start, end);
      final loaded = await Future.wait(
        batch.map((variant) async {
          final id = JsonReader.integer(variant, 'id') ?? 0;
          final sku = JsonReader.string(variant, 'sku')?.trim();
          if (id <= 0 || sku == null || sku.isEmpty) return null;

          try {
            final stock = await _loadStockByVariantId(
              token: token,
              variantId: id,
              sku: sku,
            );
            return ProductVariantStock.fromJson(variant, stock: stock);
          } on ApiException {
            return ProductVariantStock.fromJson(
              variant,
              stock: const ProductStock(),
            );
          }
        }),
      );
      products.addAll(loaded.whereType<ProductVariantStock>());
    }

    return products..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Loads one variant from its detail endpoint and combines its inventory
  /// records across warehouses.
  Future<ProductVariantStock> variantDetails(int variantId) async {
    if (variantId <= 0) {
      throw const ProductVariantApiException('Sản phẩm không hợp lệ.');
    }

    final token = _currentToken();
    try {
      final results = await Future.wait([
        _apiClient.get('/api/v1/product-variant/$variantId', token: token),
        _apiClient.get(
          '/api/v1/inventories/by-variant/$variantId',
          token: token,
        ),
      ]);
      final variant = JsonReader.map(results[0], 'resources');
      if (variant == null) {
        throw const ProductVariantApiException(
          'API không trả về chi tiết sản phẩm.',
        );
      }
      final inventoryResources = JsonReader.value(results[1], 'resources');
      final stock = inventoryResources is List
          ? ProductStock.fromInventoryList(inventoryResources)
          : const ProductStock();
      return ProductVariantStock.fromJson(variant, stock: stock);
    } on ApiException catch (error) {
      throw ProductVariantApiException(error.message);
    }
  }

  /// Màn nhập kho ưu tiên sản phẩm còn ít hàng nhất để người dùng nhập bổ sung.
  Future<ProductVariantStock> firstVariantForThuMua() async {
    final products = await activeVariantsWithStock();
    if (products.isEmpty) {
      throw const ProductVariantApiException(
        'Chưa có sản phẩm đang hoạt động để nhập kho.',
      );
    }

    products.sort((a, b) {
      final stockCompare = a.quantityAvailable.compareTo(b.quantityAvailable);
      return stockCompare != 0 ? stockCompare : a.name.compareTo(b.name);
    });
    return products.first;
  }

  /// Màn xuất kho chỉ chọn sản phẩm còn tồn khả dụng.
  Future<ProductVariantStock> firstVariantForGiaoHang() async {
    final products = await activeVariantsWithStock();
    final availableProducts = products
        .where((product) => product.quantityAvailable > 0)
        .toList()
      ..sort((a, b) => b.quantityAvailable.compareTo(a.quantityAvailable));

    if (availableProducts.isEmpty) {
      throw const ProductVariantApiException(
        'Hiện chưa có sản phẩm nào còn tồn để xuất kho.',
      );
    }

    return availableProducts.first;
  }

  /// Dùng cho màn chi tiết sản phẩm hoặc các nơi chỉ cần một sản phẩm mẫu.
  Future<ProductVariantStock> firstActiveVariantWithStock() {
    return firstVariantForThuMua();
  }

  Future<ProductStock> loadStockBySku(String sku) async {
    final token = _currentToken();
    return _loadStockBySku(token: token, sku: sku);
  }

  String _currentToken() {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ProductVariantApiException(
        'Bạn cần đăng nhập để tải dữ liệu sản phẩm.',
      );
    }
    return token;
  }

  Future<List<Map<String, dynamic>>> _loadActiveVariants(String token) async {
    final json = await _apiClient.get(
      '/api/v1/product-variant/search',
      token: token,
      query: {
        'pageIndex': '1',
        'pageSize': pageSize.toString(),
        'isActive': 'true',
      },
    );

    final resources = JsonReader.map(json, 'resources');
    if (resources == null) return const [];

    final dataSource = JsonReader.list(resources, 'dataSource') ?? const [];
    return [
      for (final item in dataSource)
        if (item is Map<String, dynamic>) item,
    ];
  }

  Future<ProductStock> _loadStockByVariantId({
    required String token,
    required int variantId,
    required String sku,
  }) async {
    try {
      final json = await _apiClient.get(
        '/api/v1/inventories/by-variant/$variantId',
        token: token,
        retryTransient: false,
      );

      final resources = JsonReader.value(json, 'resources');
      if (resources is List) {
        return ProductStock.fromInventoryList(resources);
      }
      if (resources is Map<String, dynamic>) {
        return ProductStock.fromJson(resources);
      }
    } on ApiException catch (error) {
      if (error.isTransient) return const ProductStock();
      return _loadStockBySku(token: token, sku: sku);
    }

    return const ProductStock();
  }

  Future<ProductStock> _loadStockBySku({
    required String token,
    required String sku,
  }) async {
    final json = await _apiClient.get(
      '/api/v1/product-variant/check-sku',
      token: token,
      query: {'sku': sku},
    );

    final resources = JsonReader.map(json, 'resources');
    if (resources == null) return const ProductStock();
    return ProductStock.fromJson(resources);
  }
}

class ProductVariantStock {
  const ProductVariantStock({
    required this.id,
    required this.name,
    required this.sku,
    required this.weightKg,
    required this.quantityOnHand,
    required this.quantityReserved,
    required this.quantityAvailable,
    this.productName,
    this.description,
    this.categoryName,
    this.unitName,
    this.costPrice = 0,
    this.salePrice = 0,
    this.minStockLevel,
    this.imageUrl,
    this.lastStockTakeDate,
    this.warehouses = const [],
  });

  factory ProductVariantStock.fromJson(
    Map<String, dynamic> json, {
    required ProductStock stock,
  }) {
    final sku = JsonReader.string(json, 'sku') ?? '';
    return ProductVariantStock(
      id: JsonReader.integer(json, 'id') ?? 0,
      name: JsonReader.string(json, 'name') ??
          JsonReader.string(json, 'productName') ??
          sku,
      sku: sku,
      productName: JsonReader.string(json, 'productName'),
      description: JsonReader.string(json, 'description'),
      categoryName: JsonReader.string(json, 'productCategoryName'),
      unitName: JsonReader.string(json, 'unitOfMeasureName'),
      costPrice: JsonReader.decimal(json, 'costPrice') ?? 0,
      salePrice: JsonReader.decimal(json, 'salePrice') ?? 0,
      minStockLevel: JsonReader.decimal(json, 'minStockLevel'),
      imageUrl: JsonReader.string(json, 'imageUrl'),
      weightKg: JsonReader.decimal(json, 'weight') ?? 0,
      quantityOnHand: stock.quantityOnHand,
      quantityReserved: stock.quantityReserved,
      quantityAvailable: stock.quantityAvailable,
      lastStockTakeDate: stock.lastStockTakeDate,
      warehouses: stock.warehouses,
    );
  }

  final int id;
  final String name;
  final String sku;
  final String? productName;
  final String? description;
  final String? categoryName;
  final String? unitName;
  final double costPrice;
  final double salePrice;
  final double? minStockLevel;
  final String? imageUrl;
  final double weightKg;
  final int quantityOnHand;
  final int quantityReserved;
  final int quantityAvailable;
  final DateTime? lastStockTakeDate;
  final List<WarehouseInventory> warehouses;
}

class ProductStock {
  const ProductStock({
    this.quantityOnHand = 0,
    this.quantityReserved = 0,
    this.quantityAvailable = 0,
    this.lastStockTakeDate,
    this.warehouses = const [],
  });

  factory ProductStock.fromJson(Map<String, dynamic> json) {
    final onHand = JsonReader.integer(json, 'quantityOnHand') ?? 0;
    final reserved = JsonReader.integer(json, 'quantityReserved') ?? 0;
    return ProductStock(
      quantityOnHand: onHand,
      quantityReserved: reserved,
      quantityAvailable:
          JsonReader.integer(json, 'quantityAvailable') ?? onHand - reserved,
      lastStockTakeDate: _readDate(json, 'lastStockTakeDate'),
      warehouses: [WarehouseInventory.fromJson(json)],
    );
  }

  factory ProductStock.fromInventoryList(List<dynamic> items) {
    var onHand = 0;
    var reserved = 0;
    DateTime? latestStockTake;
    final warehouses = <WarehouseInventory>[];

    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      onHand += JsonReader.integer(item, 'quantityOnHand') ?? 0;
      reserved += JsonReader.integer(item, 'quantityReserved') ?? 0;
      final warehouse = WarehouseInventory.fromJson(item);
      warehouses.add(warehouse);
      final checkedAt = warehouse.lastStockTakeDate;
      if (checkedAt != null &&
          (latestStockTake == null || checkedAt.isAfter(latestStockTake))) {
        latestStockTake = checkedAt;
      }
    }

    return ProductStock(
      quantityOnHand: onHand,
      quantityReserved: reserved,
      quantityAvailable: onHand - reserved,
      lastStockTakeDate: latestStockTake,
      warehouses: warehouses,
    );
  }

  final int quantityOnHand;
  final int quantityReserved;
  final int quantityAvailable;
  final DateTime? lastStockTakeDate;
  final List<WarehouseInventory> warehouses;
}

class WarehouseInventory {
  const WarehouseInventory({
    required this.inventoryId,
    required this.warehouseId,
    required this.warehouseName,
    required this.quantityOnHand,
    required this.quantityReserved,
    required this.quantityAvailable,
    this.locationCode,
    this.locationId,
    this.lastStockTakeDate,
  });

  factory WarehouseInventory.fromJson(Map<String, dynamic> json) {
    final onHand = JsonReader.integer(json, 'quantityOnHand') ?? 0;
    final reserved = JsonReader.integer(json, 'quantityReserved') ?? 0;
    return WarehouseInventory(
      inventoryId: JsonReader.integer(json, 'id') ?? 0,
      warehouseId: JsonReader.integer(json, 'warehouseId') ?? 0,
      warehouseName:
          JsonReader.string(json, 'warehouseName') ?? 'Kho chưa xác định',
      locationCode: JsonReader.string(json, 'locationCode'),
      locationId: JsonReader.integer(json, 'locationId'),
      quantityOnHand: onHand,
      quantityReserved: reserved,
      quantityAvailable:
          JsonReader.integer(json, 'quantityAvailable') ?? onHand - reserved,
      lastStockTakeDate: _readDate(json, 'lastStockTakeDate'),
    );
  }

  final int inventoryId;
  final int warehouseId;
  final String warehouseName;
  final String? locationCode;
  final int? locationId;
  final int quantityOnHand;
  final int quantityReserved;
  final int quantityAvailable;
  final DateTime? lastStockTakeDate;
}

DateTime? _readDate(Map<String, dynamic> json, String key) {
  final value = JsonReader.string(json, key);
  return value == null ? null : DateTime.tryParse(value)?.toLocal();
}

class ProductVariantApiException implements Exception {
  const ProductVariantApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
