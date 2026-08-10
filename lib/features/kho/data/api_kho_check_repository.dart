import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../../products/data/product_variant_api.dart';
import '../models/kho_check.dart';
import 'kho_check_repository.dart';

/// StockTake repository. A stocktake always belongs to exactly one warehouse.
class ApiKhoCheckRepository
    implements KhoCheckRepository, StockTakeSubmitRepository {
  ApiKhoCheckRepository({
    ProductVariantApi? productVariantApi,
    ApiClient? apiClient,
  })  : _productVariantApi = productVariantApi ?? ProductVariantApi(),
        _apiClient = apiClient ?? ApiClient();

  final ProductVariantApi _productVariantApi;
  final ApiClient _apiClient;

  Future<KhoCheck?> _loadExistingDraft() async {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) return null;
    try {
      final json = await _apiClient.get('/api/v1/stocktake', token: token);
      final resources = JsonReader.value(json, 'resources');
      if (resources is! List) return null;
      Map<String, dynamic>? draft;
      for (final value in resources.whereType<Map<String, dynamic>>()) {
        final statusId = JsonReader.integer(value, 'stockTakeStatusId');
        final status = (JsonReader.string(value, 'stockTakeStatusCode') ??
                JsonReader.string(value, 'stockTakeStatusName') ??
                '')
            .toLowerCase();
        if (statusId == 1 || status == 'draft' || status.contains('nháp')) {
          draft = value;
          break;
        }
      }
      if (draft == null) return null;

      final warehouseId = JsonReader.integer(draft, 'warehouseId') ?? 0;
      List<ProductVariantStock> products;
      try {
        products = await _productVariantApi.activeVariantsWithStock();
      } on ProductVariantApiException {
        products = const [];
      }
      final productById = {
        for (final product in products) product.id: product,
      };
      final rawItems = JsonReader.list(draft, 'stockTakeItems') ?? const [];
      final items = <KhoCheckItem>[];
      for (final raw in rawItems.whereType<Map<String, dynamic>>()) {
        final productId = JsonReader.integer(raw, 'productVariantId') ?? 0;
        final product = productById[productId];
        final actual = JsonReader.decimal(raw, 'actualQuantity');
        items.add(
          KhoCheckItem(
            id: JsonReader.integer(raw, 'id') ?? 0,
            productVariantId: productId,
            productName: JsonReader.string(raw, 'productVariantName') ??
                product?.name ??
                'Sản phẩm $productId',
            sku: JsonReader.string(raw, 'sku') ?? product?.sku ?? '',
            systemQuantity:
                JsonReader.decimal(raw, 'systemQuantity')?.round() ?? 0,
            locationId: JsonReader.integer(raw, 'locationId'),
            paddyLotId: JsonReader.integer(raw, 'paddyLotId'),
            actualQuantity: actual?.round(),
            lastStockTakeDate: product?.lastStockTakeDate,
            unitLabel: product?.unitName?.trim().isNotEmpty == true
                ? product!.unitName!.trim()
                : 'kg',
          ),
        );
      }
      return KhoCheck(
        id: JsonReader.integer(draft, 'id') ?? 0,
        statusId: JsonReader.integer(draft, 'stockTakeStatusId') ?? 1,
        status: JsonReader.string(draft, 'stockTakeStatusName') ?? 'Phiếu nháp',
        note: JsonReader.string(draft, 'note'),
        warehouseId: warehouseId,
        checkCode: JsonReader.string(draft, 'stCode') ?? 'ST-DRAFT',
        warehouseName:
            JsonReader.string(draft, 'warehouseName') ?? 'Kho $warehouseId',
        noteHint: 'Nhập ghi chú kiểm kê...',
        checkedAt: DateTime.tryParse(
              JsonReader.string(draft, 'startedDate') ??
                  JsonReader.string(draft, 'createdDate') ??
                  '',
            ) ??
            DateTime.now(),
        items: items,
      );
    } on ApiException {
      return null;
    }
  }

  @override
  Future<KhoCheck> getDraftCheck() async {
    final existing = await _loadExistingDraft();
    if (existing != null && existing.items.isNotEmpty) return existing;
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
            unitLabel: entry.product.unitName?.trim().isNotEmpty == true
                ? entry.product.unitName!.trim()
                : 'kg',
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
          'stockTakeStatusId': 1,
          'note': note?.trim(),
          'stockTakeItems': [
            for (final item in items)
              {
                'productVariantId': item.productVariantId,
                'locationId': item.locationId,
                'paddyLotId': item.paddyLotId,
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

  @override
  Future<void> submitStockTake({
    required int stockTakeId,
    required KhoCheck check,
    required List<KhoCheckItem> items,
    String? note,
  }) async {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const KhoCheckException(
        'Bạn cần đăng nhập để gửi phiếu kiểm kê.',
      );
    }
    if (stockTakeId <= 0) {
      throw const KhoCheckException('Phiếu kiểm kê chưa được tạo nháp.');
    }
    try {
      final response = await _apiClient.put(
        '/api/v1/stocktake',
        token: token,
        body: {
          'id': stockTakeId,
          'stockTakeStatusId': 2,
          'note': note?.trim(),
          'startedDate': check.checkedAt.toIso8601String(),
          'stockTakeItems': [
            for (final item in items)
              {
                'id': item.id,
                'productVariantId': item.productVariantId,
                'locationId': item.locationId,
                'paddyLotId': item.paddyLotId,
                'actualQuantity': item.actualQuantity,
                'note': null,
                'qrScanned': false,
                'recountConfirmed': false,
              },
          ],
        },
      );
      if (JsonReader.boolean(response, 'isSucceeded') == false) {
        throw KhoCheckException(
          JsonReader.string(response, 'message') ??
              'Không gửi được phiếu kiểm kê.',
        );
      }
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
