import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../../kho/models/inventory_stock.dart';
import '../models/stock_take.dart';
import 'stock_take_repository.dart';
import '../../kho/models/stock_take.dart' as legacy;

class ApiStockTakeRepository implements StockTakeRepository {
  ApiStockTakeRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  String _currentToken() {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    return token;
  }

  @override
  Future<StockTakePage> getStockTakesPaged({
    required int start,
    required int length,
    String? search,
    int? warehouseId,
    String? statusCode,
  }) async {
    final token = _currentToken();

    final body = {
      'draw': 1,
      'start': start < 0 ? 0 : start,
      'length': length <= 0 ? 20 : length,
      'columns': [
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
          'data': 'stockTakeStatusCode',
          'name': '',
          'searchable': true,
          'orderable': true,
          'search': {
            'value': statusCode ?? '',
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
      'search': {'value': (search ?? '').trim(), 'regex': false},
    };

    final json = await _apiClient.post(
      '/api/v1/stocktakes/paged-advanced',
      token: token,
      body: body,
    );

    final resources = JsonReader.map(json, 'resources') ?? json;
    final rows = JsonReader.list(resources, 'data') ??
        JsonReader.list(json, 'data') ??
        const [];

    return StockTakePage(
      items: [
        for (final item in rows)
          if (item is Map<String, dynamic>) StockTakeSummary.fromJson(item),
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
  @override
  Future<legacy.StockTakeDetail> getStockTakeDetail(int id) async {
    final token = _currentToken();
    final json = await _apiClient.get(
      '/api/v1/stocktakes/$id',
      token: token,
    );
    final resources = JsonReader.map(json, 'resources') ?? json;
    return legacy.StockTakeDetail.fromJson(resources);
  }

  @override
  Future<List<WarehouseOption>> getWarehouses() async {
    final token = _currentToken();
    final json = await _apiClient.get(
      '/api/v1/warehouse',
      token: token,
    );
    final resources = JsonReader.list(json, 'resources') ??
        JsonReader.list(json, 'data') ??
        const [];
    return [
      for (final item in resources)
        if (item is Map<String, dynamic>) WarehouseOption.fromJson(item),
    ];
  }

  @override
  Future<List<StockTakeStatusOption>> getStatuses() async {
    try {
      final token = _currentToken();
      final json = await _apiClient.get(
        '/api/v1/stocktakes/statuses',
        token: token,
      );
      final resources = JsonReader.list(json, 'resources') ??
          JsonReader.list(json, 'data') ??
          const [];
      if (resources.isNotEmpty) {
        return [
          for (final item in resources)
            if (item is Map<String, dynamic>)
              StockTakeStatusOption(
                code: JsonReader.string(item, 'code') ?? JsonReader.string(item, 'statusCode') ?? '',
                name: JsonReader.string(item, 'name') ?? JsonReader.string(item, 'statusName') ?? '',
              ),
        ];
      }
    } catch (_) {}
    return const [
      StockTakeStatusOption(code: 'DRAFT', name: 'Nháp'),
      StockTakeStatusOption(code: 'COUNTING', name: 'Đang kiểm'),
      StockTakeStatusOption(code: 'SUBMITTED', name: 'Chờ duyệt'),
      StockTakeStatusOption(code: 'APPROVED', name: 'Đã duyệt'),
      StockTakeStatusOption(code: 'REJECTED', name: 'Từ chối'),
    ];
  }

  @override
  Future<List<StockTakeLocationOption>> getLocations(int warehouseId) async {
    try {
      final token = _currentToken();
      final json = await _apiClient.get(
        '/api/v1/location',
        token: token,
      );
      final resources = JsonReader.value(json, 'resources');
      final rows = switch (resources) {
        List<dynamic> items => items,
        Map<String, dynamic> page => JsonReader.list(page, 'data') ?? const [],
        _ => const <dynamic>[],
      };
      final options = <StockTakeLocationOption>[];
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final id = JsonReader.integer(row, 'id') ?? 0;
        final wh = JsonReader.integer(row, 'warehouseId') ?? 0;
        if (id <= 0 || wh != warehouseId) continue;
        final zone = JsonReader.string(row, 'zoneName') ?? '';
        final slot = JsonReader.string(row, 'slotCode') ??
            [
              JsonReader.string(row, 'shelfRow'),
              JsonReader.string(row, 'shelfLevel'),
            ].where((x) => (x ?? '').isNotEmpty).join('-');
        options.add(StockTakeLocationOption(
          id: id,
          warehouseId: wh,
          zoneName: zone,
          label: [zone, slot].where((x) => x.isNotEmpty).join(' / '),
        ));
      }
      options.sort((a, b) => a.label.compareTo(b.label));
      return options;
    } on ApiException {
      return const [];
    }
  }

  @override
  Future<List<StockTakeOption>> getLots() async {
    try {
      final token = _currentToken();
      final json = await _apiClient.get(
        '/api/v1/paddy-lots',
        token: token,
      );
      final resources = JsonReader.value(json, 'resources');
      final rows = switch (resources) {
        List<dynamic> items => items,
        Map<String, dynamic> page => JsonReader.list(page, 'data') ?? const [],
        _ => const <dynamic>[],
      };
      final options = <StockTakeOption>[];
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final id = JsonReader.integer(row, 'id') ?? 0;
        final code = JsonReader.string(row, 'lotCode') ??
            JsonReader.string(row, 'code') ??
            '';
        if (code.isEmpty) continue;
        options.add(StockTakeOption(
          id: id,
          code: code,
          label: code,
        ));
      }
      options.sort((a, b) => a.label.compareTo(b.label));
      return options;
    } on ApiException {
      return const [];
    }
  }

  @override
  Future<List<StockTakeOption>> getSkus() async {
    try {
      final token = _currentToken();
      final json = await _apiClient.get(
        '/api/v1/product-variant',
        token: token,
      );
      final resources = JsonReader.value(json, 'resources');
      final rows = switch (resources) {
        List<dynamic> items => items,
        Map<String, dynamic> page => JsonReader.list(page, 'data') ?? const [],
        _ => const <dynamic>[],
      };
      final options = <StockTakeOption>[];
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final id = JsonReader.integer(row, 'id') ?? 0;
        final sku = JsonReader.string(row, 'sku') ??
            JsonReader.string(row, 'code') ??
            '';
        final name = JsonReader.string(row, 'variantName') ??
            JsonReader.string(row, 'productName') ??
            JsonReader.string(row, 'name') ??
            sku;
        if (sku.isEmpty && name.isEmpty) continue;
        final label = sku.isEmpty ? name : '$sku - $name';
        options.add(StockTakeOption(
          id: id,
          code: sku.isEmpty ? name : sku,
          label: label,
        ));
      }
      options.sort((a, b) => a.label.compareTo(b.label));
      return options;
    } on ApiException {
      return const [];
    }
  }

  @override
  Future<int> create({
    required int warehouseId,
    required StockTakeScope scope,
    String? zoneName,
    int? locationId,
    int? paddyLotId,
    int? productVariantId,
    String? lotCode,
    String? skuCode,
    String? note,
  }) async {
    final token = _currentToken();
    final json = await _apiClient.post(
      '/api/v1/stocktakes',
      token: token,
      body: {
        'warehouseId': warehouseId,
        'stockTakeStatusId': 0,
        'scopeType': scope.code,
        if (zoneName != null) 'zoneName': zoneName,
        if (locationId != null) 'locationId': locationId,
        if (paddyLotId != null) 'paddyLotId': paddyLotId,
        if (productVariantId != null) 'productVariantId': productVariantId,
        if (lotCode != null) 'lotCode': lotCode,
        if (skuCode != null) 'skuCode': skuCode,
        'note': note?.trim(),
        'stockTakeItems': const <dynamic>[],
      },
    );
    final resources = JsonReader.value(json, 'resources');
    if (resources is num) return resources.toInt();
    if (resources is Map<String, dynamic>) {
      return JsonReader.integer(resources, 'id') ?? 0;
    }
    return 0;
  }

  @override
  Future<void> saveCounts(int id, List<legacy.StockTakeLine> lines, {String? note}) async {
    final token = _currentToken();
    await _apiClient.put(
      '/api/v1/stocktakes/$id/counts',
      token: token,
      body: {
        'note': note?.trim(),
        'items': [for (final line in lines) line.toSaveJson()],
      },
    );
  }

  @override
  Future<void> submit(int id, {String? note}) async {
    final token = _currentToken();
    await _apiClient.put(
      '/api/v1/stocktakes/$id/submit',
      token: token,
      body: {'note': note?.trim()},
    );
  }

  @override
  Future<legacy.ScanBagResult> scanBag(int id, String qrCode) async {
    final token = _currentToken();
    final json = await _apiClient.post(
      '/api/v1/stocktakes/$id/scan-bag',
      token: token,
      body: {'qrCode': qrCode.trim()},
    );
    final resources = JsonReader.map(json, 'resources');
    if (resources == null) {
      return const legacy.ScanBagResult(
        matched: false,
        message: 'Không đọc được kết quả tra mã.',
      );
    }
    return legacy.ScanBagResult.fromJson(resources);
  }
}
