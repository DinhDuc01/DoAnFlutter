import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../../products/data/product_variant_api.dart';
import '../models/kho_check.dart';
import 'kho_check_repository.dart';

/// StockTake repository. A stocktake always belongs to exactly one warehouse.
class ApiKhoCheckRepository implements KhoCheckRepository {
  ApiKhoCheckRepository({
    ProductVariantApi? productVariantApi,
    ApiClient? apiClient,
  })  : _productVariantApi = productVariantApi ?? ProductVariantApi(),
        _apiClient = apiClient ?? ApiClient();

  final ProductVariantApi _productVariantApi;
  final ApiClient _apiClient;

  @override
  Future<KhoCheck> getDraftCheck() async {
    final List<ProductVariantStock> products;
    try {
      products = await _productVariantApi.activeVariantsWithStock();
    } on ProductVariantApiException catch (error) {
      throw KhoCheckException(error.message);
    }

    final inventories = products
        .expand(
          (product) => product.warehouses.map((inventory) => (
                product: product,
                inventory: inventory,
              )),
        )
        .where(
          (entry) =>
              entry.inventory.warehouseId > 0 &&
              entry.inventory.quantityOnHand > 0,
        )
        .toList();
    if (inventories.isEmpty) {
      throw const KhoCheckException(
        'Không có tồn kho thực tế để tạo phiếu kiểm kê.',
      );
    }

    final totals = <int, int>{};
    for (final entry in inventories) {
      totals.update(
        entry.inventory.warehouseId,
        (value) => value + entry.inventory.quantityOnHand,
        ifAbsent: () => entry.inventory.quantityOnHand,
      );
    }
    final warehouseId = totals.entries
        .reduce((left, right) => left.value >= right.value ? left : right)
        .key;
    final selected = inventories
        .where((entry) => entry.inventory.warehouseId == warehouseId)
        .toList();
    final now = DateTime.now();

    return KhoCheck(
      warehouseId: warehouseId,
      checkCode: 'ST-${now.year}${now.month.toString().padLeft(2, '0')}',
      warehouseName: selected.first.inventory.warehouseName,
      noteHint: 'Nhập ghi chú kiểm kê...',
      checkedAt: now,
      items: [
        for (final entry in selected)
          KhoCheckItem(
            productVariantId: entry.product.id,
            productName: entry.product.name,
            sku: entry.product.sku,
            systemQuantity: entry.inventory.quantityOnHand,
            locationId: entry.inventory.locationId,
            lastStockTakeDate: entry.inventory.lastStockTakeDate,
          ),
      ],
    );
  }

  @override
  Future<int> createStockTake({
    required KhoCheck check,
    required List<KhoCheckItem> items,
    String? note,
  }) async {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const KhoCheckException('Bạn cần đăng nhập để tạo phiếu kiểm kê.');
    }
    try {
      final response = await _apiClient.post(
        '/api/v1/stocktake',
        token: token,
        body: {
          'warehouseId': check.warehouseId,
          'stockTakeStatusId': 0,
          'note': note?.trim(),
          'stockTakeItems': [
            for (final item in items)
              {
                'productVariantId': item.productVariantId,
                'locationId': item.locationId,
                'systemQuantity': item.systemQuantity,
                'actualQuantity': item.actualQuantity,
                'note': null,
                'qrScanned': false,
              },
          ],
        },
      );
      final resources = JsonReader.value(response, 'resources');
      if (resources is int) return resources;
      if (resources is num) return resources.toInt();
      if (resources is Map<String, dynamic>) {
        return JsonReader.integer(resources, 'id') ?? 0;
      }
      return 0;
    } on ApiException catch (error) {
      throw KhoCheckException(error.message);
    }
  }
}

class KhoCheckException implements Exception {
  const KhoCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}
