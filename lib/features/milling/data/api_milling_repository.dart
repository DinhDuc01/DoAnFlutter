import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../../products/data/product_variant_api.dart';
import '../models/milling_order.dart';
import 'milling_repository.dart';

class ApiMillingRepository implements MillingRepository {
  ApiMillingRepository({
    ApiClient? apiClient,
    ProductVariantApi? productVariantApi,
  })  : _apiClient = apiClient ?? ApiClient(),
        _productVariantApi = productVariantApi ?? ProductVariantApi();

  final ApiClient _apiClient;
  final ProductVariantApi _productVariantApi;

  @override
  Future<List<MillingPaddyLotOption>> getPaddyLots() async {
    final json = await _apiClient.get(
      '/api/v1/paddy-lots',
      token: _currentToken(),
    );
    final resources = JsonReader.list(json, 'resources') ?? const [];
    return [
      for (final item in resources.whereType<Map<String, dynamic>>())
        if ((JsonReader.decimal(item, 'remainingWeightKg') ?? 0) > 0 &&
            (JsonReader.string(item, 'lotType') ?? '')
                .toUpperCase()
                .contains('PADDY'))
          MillingPaddyLotOption(
            id: JsonReader.integer(item, 'id') ?? 0,
            code: JsonReader.string(item, 'lotCode') ?? 'Lô lúa',
            warehouseId: JsonReader.integer(item, 'warehouseId') ?? 0,
            warehouseName:
                JsonReader.string(item, 'warehouseName') ?? 'Kho lúa',
            locationId: JsonReader.integer(item, 'locationId'),
            locationCode: JsonReader.string(item, 'locationCode'),
            riceVarietyId: JsonReader.integer(item, 'riceVarietyId'),
            riceVarietyName: JsonReader.string(item, 'riceVarietyName'),
            remainingWeightKg:
                JsonReader.decimal(item, 'remainingWeightKg') ?? 0,
          ),
    ].where((item) => item.id > 0 && item.warehouseId > 0).toList()
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  @override
  Future<int> createOrder({
    required MillingPaddyLotOption lot,
    required double inputWeightKg,
    required double expectedYield,
    String? reason,
    double? moisturePercent,
    double? millingCost,
    double? incidentalCost,
    DateTime? expectedCompletionDate,
  }) async {
    _validateCreateInput(lot, inputWeightKg, expectedYield);
    final body = <String, dynamic>{
      'warehouseId': lot.warehouseId,
      'riceVarietyId': lot.riceVarietyId,
      'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
      'expectedYield': expectedYield,
      'targetRiceKg': inputWeightKg * expectedYield,
      if (moisturePercent != null) 'moisturePercent': moisturePercent,
      if (millingCost != null) 'millingCost': millingCost,
      if (incidentalCost != null) 'incidentalCost': incidentalCost,
      if (expectedCompletionDate != null)
        'expectedCompletionDate': expectedCompletionDate.toIso8601String(),
    };
    final response = await _apiClient.post(
      '/api/v1/milling-orders',
      token: _currentToken(),
      body: body,
    );
    _ensureSucceeded(response, 'Không tạo được lệnh xay.');
    final id = _resourceId(response);
    if (id <= 0) {
      throw const MillingApiException('Backend không trả về mã lệnh xay.');
    }
    return id;
  }

  Future<int> createAndStartOrder({
    required MillingPaddyLotOption lot,
    required double inputWeightKg,
    required double expectedYield,
  }) async {
    _validateCreateInput(lot, inputWeightKg, expectedYield);
    final token = _currentToken();
    final id = await createOrder(
      lot: lot,
      inputWeightKg: inputWeightKg,
      expectedYield: expectedYield,
      reason: 'Tạo lệnh xay từ ứng dụng mobile',
    );

    final reserved = await _apiClient.post(
      '/api/v1/milling-orders/$id/reserve',
      token: token,
      body: {
        'inputs': [
          {
            'paddyLotId': lot.id,
            'locationId': lot.locationId,
            'consumedWeightKg': inputWeightKg,
            'reservedWeightKg': inputWeightKg,
            'note': 'Lúa đầu vào chọn trên mobile',
          },
        ],
      },
    );
    _ensureSucceeded(reserved, 'Không giữ được lúa cho lệnh xay.');

    final started = await _apiClient.post(
      '/api/v1/milling-orders/$id/start',
      token: token,
      body: const {},
    );
    _ensureSucceeded(started, 'Không bắt đầu được lệnh xay.');
    return id;
  }

  static void _validateCreateInput(
    MillingPaddyLotOption lot,
    double inputWeightKg,
    double expectedYield,
  ) {
    if (!inputWeightKg.isFinite ||
        inputWeightKg <= 0 ||
        inputWeightKg > lot.remainingWeightKg) {
      throw MillingApiException(
        'Khối lượng lúa phải lớn hơn 0 và không vượt quá '
        '${lot.remainingWeightKg.toStringAsFixed(1)} kg.',
      );
    }
    if (!expectedYield.isFinite || expectedYield <= 0 || expectedYield > 1) {
      throw const MillingApiException(
          'Tỷ lệ thu hồi phải trong khoảng 1-100%.');
    }
    if (lot.riceVarietyId == null || lot.riceVarietyId! <= 0) {
      throw const MillingApiException('Lô chưa có giống lúa hợp lệ.');
    }
  }

  @override
  Future<List<MillingProductOption>> getOutputProducts() async {
    final products = await _productVariantApi.activeVariantsWithStock();
    return [
      for (final product in products)
        MillingProductOption(
          id: product.id,
          name: product.name,
          sku: product.sku,
          outputType: _outputType(product.name),
        ),
    ];
  }

  @override
  Future<MillingOrderPage> getMillingOrderPage({
    String search = '',
    int? statusId,
    int? warehouseId,
    int start = 0,
    int length = 20,
  }) async {
    final body = {
      'draw': 1,
      'start': start < 0 ? 0 : start,
      'length': length <= 0 ? 20 : length,
      'columns': [
        {
          'data': 'statusId',
          'name': '',
          'searchable': true,
          'orderable': true,
          'search': {
            'value': statusId == null ? '' : '$statusId',
            'regex': false,
          },
        },
        {
          'data': 'warehouseId',
          'name': '',
          'searchable': true,
          'orderable': true,
          'search': {
            'value': warehouseId == null ? '' : '$warehouseId',
            'regex': false,
          },
        },
        {
          'data': 'createdDate',
          'name': '',
          'searchable': false,
          'orderable': true,
          'search': {'value': '', 'regex': false},
        },
      ],
      'order': [
        {'column': 2, 'dir': 'desc'},
      ],
      'search': {'value': search.trim(), 'regex': false},
    };
    final json = await _apiClient.post(
      '/api/v1/milling-orders/paged-advanced',
      token: _currentToken(),
      body: body,
    );
    final resources = JsonReader.map(json, 'resources') ?? json;
    final rows = JsonReader.list(resources, 'data') ??
        JsonReader.list(json, 'data') ??
        const [];
    return MillingOrderPage(
      orders: [
        for (final item in rows)
          if (item is Map<String, dynamic>) MillingOrder.fromJson(item),
      ],
      recordsTotal: JsonReader.integer(resources, 'recordsTotal') ??
          JsonReader.integer(json, 'recordsTotal') ??
          rows.length,
      recordsFiltered: JsonReader.integer(resources, 'recordsFiltered') ??
          JsonReader.integer(json, 'recordsFiltered') ??
          rows.length,
    );
  }

  @override
  Future<List<MillingOrder>> getMillingOrders({
    String search = '',
    int? statusId,
    int? warehouseId,
  }) async {
    final page = await getMillingOrderPage(
      search: search,
      statusId: statusId,
      warehouseId: warehouseId,
    );
    return page.orders;
  }

  @override
  Future<MillingOrder> getMillingOrderDetail(int id) async {
    if (id <= 0) {
      throw const MillingApiException('Mã lệnh xay không hợp lệ.');
    }
    final json = await _apiClient.get(
      '/api/v1/milling-orders/$id',
      token: _currentToken(),
    );
    final detail = JsonReader.map(json, 'resources') ?? json;
    return MillingOrder.fromJson(detail);
  }

  @override
  Future<MillingOrder> getActiveOrder() async {
    final token = _currentToken();
    final json = await _apiClient.get('/api/v1/milling-orders', token: token);
    final orders = JsonReader.list(json, 'resources') ?? const [];
    final rawOrder =
        orders.cast<Object?>().whereType<Map<String, dynamic>>().firstOrNull;
    if (rawOrder == null) {
      throw const MillingApiException('Chưa có lệnh xay trên server.');
    }

    final id = JsonReader.integer(rawOrder, 'id') ?? 0;
    final detailJson = await _apiClient.get(
      '/api/v1/milling-orders/$id',
      token: token,
    );
    final detail = JsonReader.map(detailJson, 'resources') ?? rawOrder;
    return MillingOrder.fromJson(detail);
  }

  @override
  Future<void> saveRiceBags(MillingOrder order) async {}

  @override
  Future<void> saveBranBags(MillingOrder order) async {}

  @override
  Future<void> completeOrder(MillingOrder order) async {
    if (order.riceProductVariantId <= 0 || order.branProductVariantId <= 0) {
      throw const MillingApiException(
        'Vui lòng chọn sản phẩm gạo và cám trước khi hoàn tất.',
      );
    }
    final json = await _apiClient.post(
      '/api/v1/milling-orders/${order.id}/complete',
      token: _currentToken(),
      body: {
        'outputs': [
          {
            'productVariantId': order.riceProductVariantId,
            'locationId': null,
            'outputType': 'RICE',
            'outputWeightKg': order.totalRiceKg,
            'bagCount': order.riceBags.length,
            'isByproduct': false,
            'unitCost': null,
          },
          {
            'productVariantId': order.branProductVariantId,
            'locationId': null,
            'outputType': 'BRAN',
            'outputWeightKg': order.totalBranKg,
            'bagCount': order.branBags.length,
            'isByproduct': true,
            'unitCost': null,
          },
          if (order.brokenBags.isNotEmpty && order.brokenProductVariantId > 0)
            {
              'productVariantId': order.brokenProductVariantId,
              'locationId': null,
              'outputType': 'BROKEN',
              'outputWeightKg': order.totalBrokenKg,
              'bagCount': order.brokenBags.length,
              'isByproduct': true,
              'unitCost': null,
            },
        ],
      },
    );
    if (JsonReader.boolean(json, 'isSucceeded') != true) {
      throw MillingApiException(
        JsonReader.string(json, 'message') ?? 'Không hoàn thành được lệnh xay',
      );
    }
  }

  static int _resourceId(Map<String, dynamic> json) {
    final resources = JsonReader.value(json, 'resources');
    return switch (resources) {
      int value => value,
      num value => value.toInt(),
      Map<String, dynamic> value => JsonReader.integer(value, 'id') ?? 0,
      _ => 0,
    };
  }

  static void _ensureSucceeded(Map<String, dynamic> json, String fallback) {
    if (JsonReader.boolean(json, 'isSucceeded') == true) return;
    throw MillingApiException(JsonReader.string(json, 'message') ?? fallback);
  }

  static String _outputType(String name) {
    final value = name.toLowerCase();
    if (value.contains('cám')) return 'BRAN';
    if (value.contains('tấm')) return 'BROKEN';
    return 'RICE';
  }

  String _currentToken() {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const MillingApiException('Bạn cần đăng nhập để xem lệnh xay.');
    }
    return token;
  }
}

class MillingApiException implements Exception {
  const MillingApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
