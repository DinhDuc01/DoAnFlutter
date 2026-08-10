import 'dart:convert';
import 'package:flutter/foundation.dart';

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
      '/api/v1/farmers',
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
            name: JsonReader.string(item, 'name') ?? 'Nông dân',
          ),
    ].where((item) => item.id > 0).toList();
  }

  Future<List<ThuMuaDraftSummary>> getDraftReceipts() async {
    debugPrint('[ThuMua] getDraftReceipts start');
    final token = _currentToken();
    List<dynamic> resources;
    try {
      final json = await _apiClient.get(
        '/api/v1/paddy-purchase-receipts',
        token: token,
      );
      resources = _receiptRows(json);
      debugPrint('[ThuMua] receipt GET returned rows=${resources.length}');
    } on ApiException {
      debugPrint('[ThuMua] receipt GET failed; falling back to paged endpoint');
      resources = const [];
    }

    // Some backend deployments expose the same data only through the
    // DataTables endpoint. Fall back to it when the plain list is unavailable.
    if (resources.isEmpty) {
      final json = await _apiClient.post(
        '/api/v1/paddy-purchase-receipts/paged-advanced',
        token: token,
        body: {
          'draw': 1,
          'start': 0,
          'length': 1000,
          'columns': const [],
          'order': const [],
          'search': {'value': '', 'regex': false},
        },
      );
      resources = _receiptRows(json);
      debugPrint('[ThuMua] receipt paged returned rows=${resources.length}');
    }
    final drafts = <ThuMuaDraftSummary>[];
    for (final item in resources.whereType<Map<String, dynamic>>()) {
      // Some API versions omit isConfirmed but expose PaddyLotId instead.
      final confirmed = JsonReader.value(item, 'isConfirmed');
      final lotId = JsonReader.integer(item, 'paddyLotId');
      final confirmedValue = confirmed == true ||
          (confirmed is String &&
              const {'true', '1', 'yes'}.contains(confirmed.toLowerCase())) ||
          (confirmed is num && confirmed != 0) ||
          (lotId != null && lotId > 0);
      final status = (JsonReader.string(item, 'statusName') ??
              JsonReader.string(item, 'receiptStatusName') ??
              JsonReader.string(item, 'inboundStatusName') ??
              JsonReader.string(item, 'status') ??
              '')
          .toLowerCase();
      final cancelled = status.contains('cancel') ||
          status.contains('hủy') ||
          status.contains('huỷ');
      if (confirmedValue || cancelled) {
        continue;
      }
      drafts.add(
        ThuMuaDraftSummary(
          id: JsonReader.integer(item, 'id') ?? 0,
          code: JsonReader.string(item, 'receiptCode') ?? 'PPR',
          farmerName: JsonReader.string(item, 'farmerName') ?? 'Nông dân',
          riceVarietyName: JsonReader.string(item, 'riceVarietyName') ?? 'Lúa',
          actualWeightKg: JsonReader.decimal(item, 'actualWeightKg') ??
              JsonReader.decimal(item, 'weightKg') ??
              JsonReader.decimal(item, 'quantityKg') ??
              0,
          bagCount: JsonReader.integer(item, 'bagCount') ??
              JsonReader.integer(item, 'quantity') ??
              0,
          debtAmount: JsonReader.decimal(item, 'debtAmount') ?? 0,
          createdAt: DateTime.tryParse(
                JsonReader.string(item, 'createdDate') ?? '',
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    }
    drafts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    debugPrint('[ThuMua] getDraftReceipts done drafts=${drafts.length}');
    return drafts;
  }

  /// Returns all receipt states. Drafts are intentionally not mixed into the
  /// history list so the UI can offer a separate "continue submit" action.
  Future<List<ThuMuaReceiptSummary>> getReceiptSummaries() async {
    final token = _currentToken();
    List<dynamic> resources;
    try {
      final json = await _apiClient.get(
        '/api/v1/paddy-purchase-receipts',
        token: token,
      );
      resources = _receiptRows(json);
    } on ApiException {
      final json = await _apiClient.post(
        '/api/v1/paddy-purchase-receipts/paged-advanced',
        token: token,
        body: {
          'draw': 1,
          'start': 0,
          'length': 1000,
          'columns': const [],
          'order': const [],
          'search': {'value': '', 'regex': false},
        },
      );
      resources = _receiptRows(json);
    }

    final rows = [
      for (final item in resources.whereType<Map<String, dynamic>>())
        _toReceiptSummary(item),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  ThuMuaReceiptSummary _toReceiptSummary(Map<String, dynamic> item) {
    final confirmed = _asBool(JsonReader.value(item, 'isConfirmed'));
    final fullyStored = _asBool(JsonReader.value(item, 'isFullyStored'));
    final lotId = JsonReader.integer(item, 'paddyLotId');
    final explicitStatus = JsonReader.string(item, 'statusName') ??
        JsonReader.string(item, 'receiptStatusName') ??
        JsonReader.string(item, 'inboundStatusName') ??
        JsonReader.string(item, 'status');
    final statusToken = explicitStatus?.toLowerCase() ?? '';
    final isCancelled = statusToken.contains('cancel') ||
        statusToken.contains('hủy') ||
        statusToken.contains('huỷ');
    final isDraft = !isCancelled && !confirmed && (lotId == null || lotId <= 0);
    final status = explicitStatus?.trim().isNotEmpty == true
        ? explicitStatus!
        : isCancelled
            ? 'Đã hủy'
            : isDraft
                ? 'Phiếu nháp'
                : fullyStored
                    ? 'Đã nhập kho'
                    : lotId != null && lotId > 0
                        ? 'Đã chốt - chờ nhập kho'
                        : 'Đã tạo';
    return ThuMuaReceiptSummary(
      id: JsonReader.integer(item, 'id') ?? 0,
      code: JsonReader.string(item, 'receiptCode') ?? 'PPR',
      farmerName: JsonReader.string(item, 'farmerName') ?? 'Nông dân',
      riceVarietyName: JsonReader.string(item, 'riceVarietyName') ?? 'Lúa',
      actualWeightKg: JsonReader.decimal(item, 'actualWeightKg') ?? 0,
      storedWeightKg: JsonReader.decimal(item, 'storedWeightKg') ?? 0,
      remainingWeightKg: JsonReader.decimal(item, 'remainingWeightKg') ?? 0,
      status: status,
      isDraft: isDraft,
      isConfirmed: confirmed,
      isFullyStored: fullyStored,
      createdAt: DateTime.tryParse(
            JsonReader.string(item, 'createdDate') ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      scheduleId: JsonReader.integer(item, 'scheduleId'),
    );
  }

  bool _asBool(Object? value) {
    return value == true ||
        (value is num && value != 0) ||
        (value is String &&
            const {'true', '1', 'yes'}.contains(value.toLowerCase()));
  }

  List<dynamic> _receiptRows(Map<String, dynamic> json) {
    final value =
        JsonReader.value(json, 'resources') ?? JsonReader.value(json, 'data');
    if (value is List) return value;
    if (value is Map<String, dynamic>) {
      return JsonReader.list(value, 'dataSource') ??
          JsonReader.list(value, 'data') ??
          JsonReader.list(value, 'items') ??
          JsonReader.list(value, 'results') ??
          JsonReader.list(value, 'resources') ??
          const [];
    }
    // A few API gateways put the table rows directly at the response root.
    return JsonReader.list(json, 'dataSource') ??
        JsonReader.list(json, 'items') ??
        JsonReader.list(json, 'results') ??
        const [];
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
      receiptCode: 'Tự động sau khi lưu',
      weightKg: product.weightKg,
      quantity: 1,
      noteHint: 'Nhập ghi chú nếu có...',
      unitCostPrice: product.costPrice,
      expectedDate: DateTime.now().add(const Duration(days: 1)),
    );
  }

  Future<ThuMuaReceipt> getDraftReceiptDetail(int id) async {
    if (id <= 0) {
      throw const InboundApiException('Mã phiếu nháp không hợp lệ.');
    }
    final json = await _apiClient.get(
      '/api/v1/paddy-purchase-receipts/$id',
      token: _currentToken(),
    );
    final data = JsonReader.map(json, 'resources');
    if (data == null) {
      throw const InboundApiException('API không trả dữ liệu phiếu nháp.');
    }
    final qualityText = JsonReader.string(data, 'qualityJson');
    Map<String, dynamic>? quality;
    if (qualityText != null && qualityText.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(qualityText);
        if (decoded is Map<String, dynamic>) quality = decoded;
      } on FormatException {
        quality = null;
      }
    }
    final farmerId = JsonReader.integer(data, 'farmerId') ?? 0;
    return ThuMuaReceipt(
      id: JsonReader.integer(data, 'id') ?? id,
      productVariantId: 0,
      warehouseId: JsonReader.integer(data, 'warehouseId') ?? 0,
      warehouseName: JsonReader.string(data, 'warehouseName') ?? '',
      status: 'Phiếu nháp',
      productName: JsonReader.string(data, 'riceVarietyName') ?? 'Lúa',
      sku: '',
      currentStock: 0,
      receiptCode: JsonReader.string(data, 'receiptCode') ?? 'PPR-$id',
      weightKg: 0,
      quantity: JsonReader.integer(data, 'bagCount') ?? 0,
      noteHint: 'Nhập ghi chú nếu có...',
      unitCostPrice: JsonReader.decimal(data, 'agreedPrice') ?? 0,
      supplier: farmerId > 0
          ? ThuMuaSupplier(
              id: farmerId,
              code: '',
              name: JsonReader.string(data, 'farmerName') ?? 'Nông dân',
            )
          : null,
      expectedDate: DateTime.tryParse(
        JsonReader.string(data, 'receiptDate') ?? '',
      ),
      scheduleId: JsonReader.integer(data, 'scheduleId'),
      riceVarietyId: JsonReader.integer(data, 'riceVarietyId'),
      actualWeightKg: JsonReader.decimal(data, 'actualWeightKg') ?? 0,
      moisturePercent: quality == null
          ? null
          : JsonReader.decimal(quality, 'moisturePercent'),
      paidAmount: JsonReader.decimal(data, 'paidAmount') ?? 0,
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

    final body = {
      if (receipt.id != null) 'id': receipt.id,
        'scheduleId': receipt.scheduleId,
        'farmerId': supplier.id,
        'riceVarietyId': receipt.riceVarietyId,
        'warehouseId': receipt.warehouseId,
        'actualWeightKg': receipt.actualWeightKg > 0
            ? receipt.actualWeightKg
            : receipt.weightKg * quantity,
        'bagCount': quantity,
        'agreedPrice': unitCostPrice,
        'totalAmount': (receipt.actualWeightKg > 0
                ? receipt.actualWeightKg
                : receipt.weightKg * quantity) *
            unitCostPrice,
        'paidAmount': receipt.paidAmount,
        'debtAmount': ((receipt.actualWeightKg > 0
                        ? receipt.actualWeightKg
                        : receipt.weightKg * quantity) *
                    unitCostPrice -
                receipt.paidAmount)
            .clamp(0, double.infinity),
        'qualityJson': receipt.moisturePercent == null
            ? null
            : jsonEncode({'moisturePercent': receipt.moisturePercent}),
        'priceAdjustReason': note.trim().isEmpty ? null : note.trim(),
        'receiptDate': receipt.expectedDate?.toIso8601String() ??
            DateTime.now().toIso8601String(),
      };
    final json = receipt.id != null
        ? await _apiClient.put(
            '/api/v1/paddy-purchase-receipts',
            token: _currentToken(),
            body: body,
          )
        : await _apiClient.post(
            '/api/v1/paddy-purchase-receipts',
            token: _currentToken(),
            body: body,
          );

    if (JsonReader.boolean(json, 'isSucceeded') != true) {
      throw InboundApiException(
        JsonReader.string(json, 'message') ?? 'Không tạo được phiếu mua lúa',
      );
    }
    final resources = JsonReader.value(json, 'resources');
    final id = switch (resources) {
      int value => value,
      num value => value.toInt(),
      Map<String, dynamic> value => JsonReader.integer(value, 'id') ?? 0,
      _ => receipt.id ?? 0,
    };
    var code = resources is Map<String, dynamic>
        ? JsonReader.string(resources, 'receiptCode')
        : null;
    if (id > 0 && (code == null || code.isEmpty)) {
      try {
        final detailJson = await _apiClient.get(
          '/api/v1/paddy-purchase-receipts/$id',
          token: _currentToken(),
        );
        final detail = JsonReader.map(detailJson, 'resources');
        code = detail == null ? null : JsonReader.string(detail, 'receiptCode');
      } on ApiException {
        // The draft still exists; the list endpoint can refresh its code later.
      }
    }
    return ThuMuaOrderSubmission(
      id: id,
      code: code ?? 'PPR-#$id',
      status: 'Phiếu nháp',
    );
  }

  @override
  Future<void> confirmPurchaseOrder(
    int orderId, {
    DateTime? dueDate,
  }) async {
    if (orderId <= 0) {
      throw const InboundApiException('Mã phiếu mua lúa không hợp lệ.');
    }
    final json = await _apiClient.post(
      '/api/v1/paddy-purchase-receipts/$orderId/confirm',
      token: _currentToken(),
      body: {
        if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
      },
    );
    if (JsonReader.boolean(json, 'isSucceeded') != true) {
      throw InboundApiException(
        JsonReader.string(json, 'message') ?? 'Không chốt được phiếu mua lúa',
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

    throw const InboundApiException(
      'Chưa xác định kho nhập. Vui lòng chọn kho trước khi lưu phiếu.',
    );
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
