import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../../products/data/product_variant_api.dart';
import '../models/thu_mua_receipt.dart';
import 'thu_mua_repository.dart';

/// Creates purchase orders in Pending state, then confirms them separately.
class ApiThuMuaRepository implements ThuMuaRepository {
  ApiThuMuaRepository({
    ProductVariantApi? productVariantApi,
    ApiClient? apiClient,
  })  : _productVariantApi = productVariantApi ?? ProductVariantApi(),
        _apiClient = apiClient ?? ApiClient();

  final ProductVariantApi _productVariantApi;
  final ApiClient _apiClient;
  Future<List<ProductVariantStock>>? _productsFuture;

  @override
  Future<List<ProductVariantStock>> getSelectableProducts() {
    return _productsFuture ??= _productVariantApi.activeVariantsWithStock();
  }

  @override
  Future<List<ThuMuaSupplier>> getSuppliers() async {
    final json = await _apiClient.get(
      '/api/v1/suppliers',
      token: _currentToken(),
    );
    final resources = JsonReader.list(json, 'resources') ?? const [];
    return [
      for (final item in resources)
        if (item is Map<String, dynamic> &&
            (JsonReader.boolean(item, 'isActive') ?? true))
          ThuMuaSupplier(
            id: JsonReader.integer(item, 'id') ?? 0,
            code: JsonReader.string(item, 'code') ?? '',
            name: JsonReader.string(item, 'name') ?? 'Nhà cung cấp',
          ),
    ].where((item) => item.id > 0).toList();
  }

  @override
  Future<ThuMuaReceipt> getDraftReceipt() async {
    final products = List<ProductVariantStock>.of(
      await getSelectableProducts(),
    )..sort((a, b) {
        final stock = a.quantityAvailable.compareTo(b.quantityAvailable);
        return stock != 0 ? stock : a.name.compareTo(b.name);
      });
    if (products.isEmpty) {
      throw const ProductVariantApiException(
        'Chưa có sản phẩm đang hoạt động để nhập kho.',
      );
    }
    return getDraftReceiptForProduct(products.first);
  }

  @override
  Future<ThuMuaReceipt> getDraftReceiptForProduct(
    ProductVariantStock product,
  ) async {
    final warehouse = await _loadDefaultWarehouse();

    return ThuMuaReceipt(
      productVariantId: product.id,
      warehouseId: warehouse.id,
      warehouseName: warehouse.name,
      status: 'Chờ xác nhận',
      productName: product.name,
      sku: product.sku,
      currentStock: product.quantityOnHand,
      receiptCode: 'PN-${DateTime.now().year}-API',
      weightKg: product.weightKg,
      quantity: 1,
      noteHint: 'Nhập ghi chú nếu có...',
      unitCostPrice: product.costPrice,
      expectedDate: DateTime.now().add(const Duration(days: 1)),
    );
  }

  @override
  Future<ThuMuaOrderSubmission> confirmInbound({
    required ThuMuaReceipt receipt,
    required int quantity,
    required double unitCostPrice,
    required String note,
  }) async {
    final supplier = receipt.supplier;
    if (supplier == null) {
      throw const InboundApiException('Vui lòng chọn nhà cung cấp.');
    }
    if (unitCostPrice <= 0) {
      throw const InboundApiException('Đơn giá nhập phải lớn hơn 0.');
    }

    final json = await _apiClient.post(
      '/api/v1/purchase-orders',
      token: _currentToken(),
      body: {
        'supplierId': supplier.id,
        'warehouseId': receipt.warehouseId,
        'expectedDate': receipt.expectedDate?.toIso8601String(),
        'note': note.trim().isEmpty ? null : note.trim(),
        'items': [
          {
            'productVariantId': receipt.productVariantId,
            'quantityOrdered': quantity,
            'unitCostPrice': unitCostPrice,
            'note': note.trim().isEmpty ? null : note.trim(),
          },
        ],
      },
    );

    if (JsonReader.boolean(json, 'isSucceeded') != true) {
      throw InboundApiException(
        JsonReader.string(json, 'message') ?? 'Không tạo được đơn mua',
      );
    }
    final resources = JsonReader.value(json, 'resources');
    final id = switch (resources) {
      int value => value,
      num value => value.toInt(),
      Map<String, dynamic> value => JsonReader.integer(value, 'id') ?? 0,
      _ => 0,
    };
    final code = resources is Map<String, dynamic>
        ? JsonReader.string(resources, 'poCode') ?? 'PO-$id'
        : 'PO-$id';
    return ThuMuaOrderSubmission(
      id: id,
      code: code,
      status: 'Chờ xác nhận',
    );
  }

  @override
  Future<void> confirmPurchaseOrder(int orderId) async {
    if (orderId <= 0) {
      throw const InboundApiException('Mã đơn mua không hợp lệ.');
    }
    final json = await _apiClient.post(
      '/api/v1/purchase-orders/$orderId/confirm',
      token: _currentToken(),
      body: const {},
    );
    if (JsonReader.boolean(json, 'isSucceeded') != true) {
      throw InboundApiException(
        JsonReader.string(json, 'message') ?? 'Không xác nhận được đơn mua',
      );
    }
  }

  Future<_InboundWarehouse> _loadDefaultWarehouse() async {
    final token = _currentToken();
    try {
      final json = await _apiClient.get('/api/v1/warehouse', token: token);
      final resources = JsonReader.value(json, 'resources');
      final first = switch (resources) {
        List<dynamic> list when list.isNotEmpty => list.first,
        Map<String, dynamic> map => map,
        _ => null,
      };

      if (first is Map<String, dynamic>) {
        final id = JsonReader.integer(first, 'id') ?? 0;
        if (id > 0) {
          return _InboundWarehouse(
            id: id,
            name: JsonReader.string(first, 'name') ??
                JsonReader.string(first, 'warehouseName') ??
                'Kho $id',
          );
        }
      }
    } on ApiException {
      // Fallback de app van co the nhap kho khi API warehouse bi chan quyen.
    }

    return const _InboundWarehouse(id: 1001, name: 'Kho mặc định');
  }

  String _currentToken() {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const InboundApiException('Bạn cần đăng nhập để nhập kho.');
    }
    return token;
  }
}

class _InboundWarehouse {
  const _InboundWarehouse({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;
}

class InboundApiException implements Exception {
  const InboundApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
