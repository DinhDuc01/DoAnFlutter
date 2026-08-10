import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../../products/data/product_variant_api.dart';
import '../models/giao_hang_receipt.dart';
import 'giao_hang_repository.dart';

class ApiGiaoHangRepository implements GiaoHangRepository {
  ApiGiaoHangRepository({
    ProductVariantApi? productVariantApi,
    ApiClient? apiClient,
  })  : _productVariantApi = productVariantApi ?? ProductVariantApi(),
        _apiClient = apiClient ?? ApiClient();

  final ProductVariantApi _productVariantApi;
  final ApiClient _apiClient;

  @override
  Future<List<GiaoHangReceipt>> getAvailableReceipts() async {
    final products = await _productVariantApi.activeVariantsWithStock();
    final now = DateTime.now();
    final receipts = <GiaoHangReceipt>[];
    for (final product in products) {
      for (final stock in product.warehouses) {
        if (stock.quantityAvailable <= 0 || stock.warehouseId <= 0) continue;
        receipts.add(
          GiaoHangReceipt(
            productVariantId: product.id,
            warehouseId: stock.warehouseId,
            warehouseName: stock.warehouseName,
            locationId: stock.locationId,
            locationCode: stock.locationCode,
            status: 'Chờ xác nhận',
            productName: product.name,
            sku: product.sku,
            currentStock: stock.quantityAvailable,
            receiptCode: 'GH-${now.millisecondsSinceEpoch}',
            quantity: 1,
            noteHint: 'Ghi chú giao hàng hoặc địa chỉ nhận...',
            unitSalePrice: product.salePrice,
            expectedDeliveryDate: now.add(const Duration(days: 1)),
          ),
        );
      }
    }
    receipts.sort((a, b) => b.currentStock.compareTo(a.currentStock));
    return receipts;
  }

  @override
  Future<GiaoHangReceipt> getDraftReceipt() async {
    final receipts = await getAvailableReceipts();
    if (receipts.isEmpty) {
      throw const GiaoHangApiException('Không có sản phẩm khả dụng để giao.');
    }
    return receipts.first;
  }

  @override
  Future<List<GiaoHangCustomer>> getCustomers() async {
    try {
      final response = await _apiClient.get(
        '/api/v1/customers',
        token: _currentToken(),
      );
      final resources = JsonReader.value(response, 'resources');
      final rows = resources is List ? resources : const <dynamic>[];
      return [
        for (final row in rows)
          if (row is Map<String, dynamic> &&
              (JsonReader.boolean(row, 'isActive') ?? true))
            GiaoHangCustomer(
              id: JsonReader.integer(row, 'id') ?? 0,
              code: JsonReader.string(row, 'code') ?? '',
              name: JsonReader.string(row, 'name') ?? 'Khách hàng',
              contactPerson: JsonReader.string(row, 'contactPerson'),
              phone: JsonReader.string(row, 'phone'),
              address: JsonReader.string(row, 'address'),
            ),
      ].where((customer) => customer.id > 0).toList();
    } on ApiException catch (error) {
      throw GiaoHangApiException(error.message);
    }
  }

  Future<List<SalesOrderDraftSummary>> getDraftSalesOrders() async {
    final json = await _apiClient.post(
      '/api/v1/sales-orders/paged',
      token: _currentToken(),
      body: {
        'pageIndex': 1,
        'pageSize': 100,
      },
    );
    final resources = JsonReader.value(json, 'resources');
    final rows = resources is Map<String, dynamic>
        ? JsonReader.list(resources, 'items') ?? const []
        : const <dynamic>[];
    final drafts = <SalesOrderDraftSummary>[];
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final statusId = JsonReader.integer(row, 'statusId') ?? 0;
      if (statusId != 1 && statusId != 2) continue;
      drafts.add(
        SalesOrderDraftSummary(
          id: JsonReader.integer(row, 'id') ?? 0,
          code: JsonReader.string(row, 'soCode') ?? 'SO',
          customerName: JsonReader.string(row, 'customerName') ?? 'Khách hàng',
          status: JsonReader.string(row, 'statusName') ?? 'Phiếu nháp',
          totalAmount: JsonReader.decimal(row, 'totalAmount') ?? 0,
          createdAt: DateTime.tryParse(
                JsonReader.string(row, 'createdDate') ?? '',
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    }
    drafts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return drafts;
  }

  @override
  Future<SalesOrderSubmission> confirmOutbound({
    required GiaoHangReceipt receipt,
    required int quantity,
    required double unitSalePrice,
    required DateTime? expectedDeliveryDate,
    required String shippingAddress,
    required String note,
  }) async {
    if (receipt.customer == null) {
      throw const GiaoHangApiException('Vui lòng chọn khách hàng nhận hàng.');
    }
    if (unitSalePrice <= 0) {
      throw const GiaoHangApiException('Đơn giá bán phải lớn hơn 0.');
    }
    if (receipt.salesMode == SalesMode.delivery &&
        expectedDeliveryDate == null) {
      throw const GiaoHangApiException('Vui lòng chọn ngày giao hàng.');
    }
    final json = await _apiClient.post(
      '/api/v1/sales-orders',
      token: _currentToken(),
      body: {
        'customerId': receipt.customer!.id,
        'warehouseId': receipt.warehouseId,
        'channel': receipt.salesMode.channel,
        'expectedDeliveryDate': receipt.salesMode == SalesMode.delivery
            ? expectedDeliveryDate?.toIso8601String()
            : null,
        'requiresMilling': false,
        'depositAmount': 0,
        'shippingAddress': receipt.salesMode == SalesMode.delivery
            ? shippingAddress.trim()
            : null,
        'note': note.trim().isEmpty ? null : note.trim(),
        'items': [
          {
            'productVariantId': receipt.productVariantId,
            'quantityOrdered': quantity,
            'unitSalePrice': unitSalePrice,
            'discountAmount': 0,
            'note': note.trim().isEmpty ? null : note.trim(),
          },
        ],
      },
    );
    if (JsonReader.boolean(json, 'isSucceeded') != true) {
      throw GiaoHangApiException(
        JsonReader.string(json, 'message') ?? 'Không tạo được đơn bán',
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
        ? JsonReader.string(resources, 'soCode') ?? 'SO-$id'
        : 'SO-$id';
    return SalesOrderSubmission(
      id: id,
      code: code,
      status: 'Chờ xác nhận',
    );
  }

  @override
  Future<void> confirmSalesOrder(int orderId) async {
    if (orderId <= 0) {
      throw const GiaoHangApiException('Mã đơn bán không hợp lệ.');
    }
    final json = await _apiClient.post(
      '/api/v1/sales-orders/$orderId/confirm',
      token: _currentToken(),
      body: const {},
    );
    if (JsonReader.boolean(json, 'isSucceeded') != true) {
      throw GiaoHangApiException(
        JsonReader.string(json, 'message') ?? 'Không xác nhận được đơn bán',
      );
    }
  }

  String _currentToken() {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const GiaoHangApiException('Bạn cần đăng nhập để giao hàng.');
    }
    return token;
  }
}

class GiaoHangApiException implements Exception {
  const GiaoHangApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
