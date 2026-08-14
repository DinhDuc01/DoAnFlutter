import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../../kho/models/inventory_stock.dart';
import '../models/stock_take.dart';
import 'stock_take_repository.dart';

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
  Future<StockTakeDetail> getStockTakeDetail(int id) async {
    final token = _currentToken();
    final json = await _apiClient.get(
      '/api/v1/stocktakes/$id',
      token: token,
    );
    final resources = JsonReader.map(json, 'resources') ?? json;
    return StockTakeDetail.fromJson(resources);
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
}
