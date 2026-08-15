import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../../products/data/product_variant_api.dart';
import '../models/milling_order.dart';
import '../models/milling_location.dart';
import '../models/milling_output_form.dart';
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
  Future<List<MillingFilterOption>> getMillingStatuses() async {
    final json = await _apiClient.get(
      '/api/v1/milling-order-status',
      token: _currentToken(),
    );
    final resources = JsonReader.list(json, 'resources') ?? const [];
    return [
      for (final item in resources.whereType<Map<String, dynamic>>())
        if ((JsonReader.integer(item, 'id') ?? 0) > 0)
          MillingFilterOption(
            id: JsonReader.integer(item, 'id')!,
            name: JsonReader.string(item, 'name') ?? 'Trạng thái',
            code: JsonReader.string(item, 'code'),
            color: JsonReader.string(item, 'color'),
          ),
    ];
  }

  @override
  Future<List<MillingFilterOption>> getWarehouses() async {
    final json = await _apiClient.get(
      '/api/v1/warehouse',
      token: _currentToken(),
    );
    final resources = JsonReader.list(json, 'resources') ?? const [];
    return [
      for (final item in resources.whereType<Map<String, dynamic>>())
        if ((JsonReader.integer(item, 'id') ?? 0) > 0 &&
            (JsonReader.boolean(item, 'isActive') ?? true))
          MillingFilterOption(
            id: JsonReader.integer(item, 'id')!,
            name: JsonReader.string(item, 'name') ?? 'Kho',
            code: JsonReader.string(item, 'code'),
          ),
    ];
  }

  /// Gợi ý nguồn lúa. Backend trả `columns[].bagIds` chính là CÁC BAO NÊN LẤY
  /// (chọn từ đỉnh cột), nên toàn bộ bao trong đó phải được tick sẵn — đó mới là
  /// "tự động chọn nguồn phù hợp" như web. Trước đây mobile chỉ tick các bao có
  /// trong `inputs` và lấy nhầm theo lô đầu tiên của cột, nên lệnh Nháp mở lên
  /// không có bao nào được chọn và luôn báo "còn thiếu".
  @override
  Future<MillingSourceSuggestion> getSourceSuggestion(int orderId) async {
    final json = await _apiClient.get(
      '/api/v1/milling-orders/$orderId/source-suggestions',
      token: _currentToken(),
    );
    final resources = JsonReader.map(json, 'resources');
    if (resources == null) {
      throw const MillingApiException('Backend không trả về nguồn lúa.');
    }
    final required = JsonReader.decimal(resources, 'requiredWeightKg') ?? 0;
    final suggested = JsonReader.decimal(resources, 'suggestedWeightKg') ?? 0;
    final missing = JsonReader.decimal(resources, 'missingWeightKg') ?? 0;
    final rawColumns = JsonReader.list(resources, 'columns') ?? const [];
    final rawInputs = JsonReader.list(resources, 'inputs') ?? const [];

    // Nạp chi tiết bao theo từng lô có trong gợi ý (mỗi lô chỉ gọi một lần).
    final bagDetailsById = <int, MillingSourceBag>{};
    final loadedLotIds = <int>{};
    for (final input in rawInputs.whereType<Map<String, dynamic>>()) {
      final lotId = JsonReader.integer(input, 'paddyLotId') ?? 0;
      if (lotId <= 0 || !loadedLotIds.add(lotId)) continue;
      final lotJson = await _apiClient.get(
        '/api/v1/paddy-lots/$lotId',
        token: _currentToken(),
      );
      final lot = JsonReader.map(lotJson, 'resources');
      for (final rawBag
          in (JsonReader.list(lot ?? const {}, 'bags') ?? const [])) {
        if (rawBag is! Map<String, dynamic>) continue;
        final bagId = JsonReader.integer(rawBag, 'id') ?? 0;
        if (bagId <= 0) continue;
        bagDetailsById[bagId] = MillingSourceBag(
          id: bagId,
          bagNo: JsonReader.integer(rawBag, 'bagNo') ?? 0,
          weightKg: JsonReader.decimal(rawBag, 'weightKg') ?? 0,
          status: JsonReader.string(rawBag, 'status') ?? '',
        );
      }
    }

    // Khối lượng dự phòng khi không đọc được chi tiết bao: chia đều theo cột.
    final columns = <MillingSourceColumn>[];
    for (final raw in rawColumns.whereType<Map<String, dynamic>>()) {
      final locationId = JsonReader.integer(raw, 'locationId') ?? 0;
      final bagIds = (JsonReader.list(raw, 'bagIds') ?? const [])
          .map((id) => id is num ? id.toInt() : int.tryParse('$id') ?? 0)
          .where((id) => id > 0)
          .toList();
      final columnWeight = JsonReader.decimal(raw, 'suggestedWeightKg') ?? 0;
      final fallbackWeight =
          bagIds.isEmpty ? 0.0 : columnWeight / bagIds.length;
      columns.add(
        MillingSourceColumn(
          locationId: locationId,
          locationCode: JsonReader.string(raw, 'locationCode'),
          bags: [
            for (final id in bagIds)
              MillingSourceBag(
                id: id,
                bagNo: bagDetailsById[id]?.bagNo ?? id,
                weightKg: bagDetailsById[id]?.weightKg ?? fallbackWeight,
                // Backend đã lọc sẵn bao lấy được ngay nên mặc định coi là
                // Stored để người dùng còn bỏ tick được nếu muốn.
                status: bagDetailsById[id]?.status ?? 'Stored',
                selected: true,
              ),
          ],
        ),
      );
    }
    return MillingSourceSuggestion(
      requiredWeightKg: required,
      columns: columns,
      suggestedWeightKg: suggested,
      missingWeightKg: missing,
    );
  }

  @override
  Future<MillingSourceSuggestion> getReservedSource(int orderId) async {
    final order = await getMillingOrderDetail(orderId);
    return MillingSourceSuggestion.fromOrderInputs(order);
  }

  @override
  Future<void> reserveOrder(
    int orderId,
    List<MillingSourceColumn> columns,
  ) async {
    final response = await _apiClient.post(
      '/api/v1/milling-orders/$orderId/reserve',
      token: _currentToken(),
      body: {
        'columns': [
          for (final column in columns)
            if (column.selectedBagIds.isNotEmpty)
              {
                'locationId': column.locationId,
                'bagIds': column.selectedBagIds,
              },
        ],
      },
    );
    _ensureSucceeded(response, 'Không giữ được bao lúa.');
  }

  @override
  Future<void> startOrder(int orderId) async {
    final response = await _apiClient.post(
      '/api/v1/milling-orders/$orderId/start',
      token: _currentToken(),
      body: const {},
    );
    _ensureSucceeded(response, 'Không bắt đầu được lệnh xay.');
  }

  @override
  Future<void> cancelOrder(int orderId) async {
    final response = await _apiClient.post(
      '/api/v1/milling-orders/$orderId/cancel',
      token: _currentToken(),
      body: const {},
    );
    _ensureSucceeded(response, 'Không hủy được lệnh xay.');
  }

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
    required int warehouseId,
    int? riceVarietyId,
    required double expectedYield,
    required double targetRiceKg,
    int? salesOrderId,
    MillingPaddyLotOption? lot,
    double? inputWeightKg,
    String? reason,
    double? moisturePercent,
    double? millingCost,
    double? incidentalCost,
    DateTime? expectedCompletionDate,
  }) async {
    if (lot != null && inputWeightKg != null) {
      _validateCreateInput(lot, inputWeightKg, expectedYield);
    } else {
      if (!expectedYield.isFinite || expectedYield <= 0 || expectedYield > 1) {
        throw const MillingApiException('Tỷ lệ thu hồi phải trong khoảng 1-100%.');
      }
      if (!targetRiceKg.isFinite || targetRiceKg <= 0) {
        throw const MillingApiException('Khối lượng gạo dự kiến phải lớn hơn 0.');
      }
    }
    final body = <String, dynamic>{
      'warehouseId': warehouseId,
      if (riceVarietyId != null) 'riceVarietyId': riceVarietyId,
      if (salesOrderId != null) 'salesOrderId': salesOrderId,
      'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
      'expectedYield': expectedYield,
      'targetRiceKg': targetRiceKg,
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

  @override
  Future<List<MillingLocation>> getLocations() async {
    final json = await _apiClient.get(
      '/api/v1/location',
      token: _currentToken(),
    );
    final resources = JsonReader.list(json, 'resources') ?? const [];
    return [
      for (final item in resources.whereType<Map<String, dynamic>>())
        MillingLocation.fromJson(item),
    ].where((location) => location.id > 0).toList();
  }

  @override
  Future<List<MillingPutawaySuggestion>> getPutawaySuggestions({
    required int warehouseId,
    required int productVariantId,
    required double requiredWeightKg,
  }) async {
    if (warehouseId <= 0 || productVariantId <= 0 ||
        !requiredWeightKg.isFinite || requiredWeightKg <= 0) {
      throw const MillingApiException('Thông tin gợi ý vị trí không hợp lệ.');
    }
    final json = await _apiClient.post(
      '/api/v1/putaway/suggestions',
      token: _currentToken(),
      body: {
        'warehouseId': warehouseId,
        'productVariantId': productVariantId,
        'paddyLotId': null,
        'requiredWeightKg': requiredWeightKg,
        'placementMode': 1,
        'top': 5,
      },
    );
    final resources = JsonReader.map(json, 'resources');
    final rows = JsonReader.list(resources ?? const {}, 'suggestions') ??
        const [];
    return [
      for (final item in rows.whereType<Map<String, dynamic>>())
        MillingPutawaySuggestion.fromJson(item),
    ].where((suggestion) => suggestion.locationId > 0).toList();
  }

  @override
  Future<void> updateOrder({
    required int id,
    required int warehouseId,
    int? riceVarietyId,
    required double expectedYield,
    required double targetRiceKg,
    int? salesOrderId,
    double? moisturePercent,
    double? millingCost,
    double? incidentalCost,
    DateTime? expectedCompletionDate,
    String? reason,
  }) async {
    if (!expectedYield.isFinite || expectedYield <= 0 || expectedYield > 1) {
      throw const MillingApiException('Tỷ lệ thu hồi phải trong khoảng 1-100%.');
    }
    if (!targetRiceKg.isFinite || targetRiceKg <= 0) {
      throw const MillingApiException('Khối lượng gạo dự kiến phải lớn hơn 0.');
    }
    final body = <String, dynamic>{
      'id': id,
      'warehouseId': warehouseId,
      if (riceVarietyId != null) 'riceVarietyId': riceVarietyId,
      if (salesOrderId != null) 'salesOrderId': salesOrderId,
      'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
      'expectedYield': expectedYield,
      'targetRiceKg': targetRiceKg,
      if (moisturePercent != null) 'moisturePercent': moisturePercent,
      if (millingCost != null) 'millingCost': millingCost,
      if (incidentalCost != null) 'incidentalCost': incidentalCost,
      if (expectedCompletionDate != null)
        'expectedCompletionDate': expectedCompletionDate.toIso8601String(),
    };
    final response = await _apiClient.put(
      '/api/v1/milling-orders',
      token: _currentToken(),
      body: body,
    );
    _ensureSucceeded(response, 'Không cập nhật được lệnh xay.');
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
  Future<void> completeOrder(
    MillingOrder order, {
    Map<String, int> outputLocationIds = const {},
    String? note,
    List<MillingOutputFormValue>? outputForms,
  }) async {
    if (outputForms != null) {
      final payload = buildMillingCompletePayloadPreview(
        outputs: outputForms,
        note: note,
      );
      final json = await _apiClient.post(
        '/api/v1/milling-orders/${order.id}/complete',
        token: _currentToken(),
        body: payload,
      );
      _ensureSucceeded(json, 'Không hoàn thành được lệnh xay.');
      return;
    }
    final outputs = <Map<String, dynamic>>[];
    void addOutput({
      required String type,
      required int productVariantId,
      required List<MillingBag> bags,
      required bool isByproduct,
    }) {
      final totalWeightKg = bags.fold<double>(
        0,
        (total, bag) => total + bag.weightKg,
      );
      if (totalWeightKg <= 0) return;
      if (productVariantId <= 0) {
        throw MillingApiException('Chưa có SKU cho output $type.');
      }
      final locationId = outputLocationIds[type];
      if (locationId == null || locationId <= 0) {
        throw MillingApiException('Chưa chọn vị trí nhập kho cho $type.');
      }
      outputs.add({
        'productVariantId': productVariantId,
        'locationId': locationId,
        'outputType': type,
        'outputWeightKg': totalWeightKg,
        'bagCount': bags.length,
        'isByproduct': isByproduct,
        'unitCost': null,
      });
    }

    addOutput(
      type: 'RICE',
      productVariantId: order.riceProductVariantId,
      bags: order.riceBags,
      isByproduct: false,
    );
    addOutput(
      type: 'BRAN',
      productVariantId: order.branProductVariantId,
      bags: order.branBags,
      isByproduct: true,
    );
    addOutput(
      type: 'BROKEN',
      productVariantId: order.brokenProductVariantId,
      bags: order.brokenBags,
      isByproduct: true,
    );
    final json = await _apiClient.post(
      '/api/v1/milling-orders/${order.id}/complete',
      token: _currentToken(),
      body: {
        'outputs': outputs,
        if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
      },
    );
    _ensureSucceeded(json, 'Không hoàn thành được lệnh xay.');
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
