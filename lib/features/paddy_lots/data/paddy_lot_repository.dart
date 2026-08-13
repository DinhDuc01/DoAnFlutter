import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/paddy_lot.dart';

/// Bộ lọc màn "Lô & truy vết". Null = không lọc theo tiêu chí đó.
class PaddyLotFilter {
  const PaddyLotFilter({
    this.keyword,
    this.lotType,
    this.warehouseId,
    this.statusId,
  });

  final String? keyword;

  /// PADDY | RICE | BYPRODUCT | PURCHASED_GOOD
  final String? lotType;
  final int? warehouseId;
  final int? statusId;

  PaddyLotFilter copyWith({
    String? keyword,
    String? lotType,
    bool clearLotType = false,
    int? warehouseId,
    bool clearWarehouse = false,
    int? statusId,
    bool clearStatus = false,
  }) =>
      PaddyLotFilter(
        keyword: keyword ?? this.keyword,
        lotType: clearLotType ? null : (lotType ?? this.lotType),
        warehouseId: clearWarehouse ? null : (warehouseId ?? this.warehouseId),
        statusId: clearStatus ? null : (statusId ?? this.statusId),
      );

  bool get isEmpty =>
      (keyword == null || keyword!.trim().isEmpty) &&
      lotType == null &&
      warehouseId == null &&
      statusId == null;
}

/// Một mục trong dropdown lọc (kho hoặc trạng thái lô).
class PaddyLotFilterOption {
  const PaddyLotFilterOption({required this.id, required this.name});

  final int id;
  final String name;
}

/// Kết quả một trang danh sách lô.
class PaddyLotPage {
  const PaddyLotPage({required this.lots, required this.totalRecords});

  final List<PaddyLotSummary> lots;
  final int totalRecords;

  bool get hasMore => lots.length < totalRecords;
}

abstract class PaddyLotRepository {
  Future<List<PaddyLotSummary>> getLots();

  /// Danh sách lô qua API lọc nâng cao — nguồn dữ liệu chính của màn danh sách.
  Future<PaddyLotPage> searchLots({
    PaddyLotFilter filter = const PaddyLotFilter(),
    int start = 0,
    int length = 100,
  });

  /// Kho và trạng thái lô để đổ vào hai dropdown lọc.
  Future<List<PaddyLotFilterOption>> getWarehouseOptions();
  Future<List<PaddyLotFilterOption>> getStatusOptions();
  Future<PaddyLotDetail> getLotDetail(int id);
  Future<PaddyLotTraceability> getTraceabilityById(int id);
  Future<PaddyLotTraceability> getTraceabilityByCode(String lotCode);
}

class ApiPaddyLotRepository implements PaddyLotRepository {
  ApiPaddyLotRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<List<PaddyLotSummary>> getLots() async {
    final json = await _get('/api/v1/paddy-lots');
    final resources = JsonReader.value(json, 'resources');
    final rows = switch (resources) {
      List<dynamic> items => items,
      Map<String, dynamic> page => JsonReader.list(page, 'dataSource') ??
          JsonReader.list(page, 'items') ??
          const <dynamic>[],
      _ => const <dynamic>[],
    };
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) PaddyLotSummary.fromJson(row),
    ].where((lot) => lot.id > 0 && lot.lotCode.isNotEmpty).toList();
  }

  /// Lấy lô qua `POST /paddy-lots/paged-advanced`.
  ///
  /// `GET /paddy-lots` (GetAllAsync) nạp entity KHÔNG kèm navigation nào, nên
  /// `warehouseName` và `statusName` luôn null — đó là lý do trước đây thẻ lô
  /// không hiện kho/trạng thái và hai dropdown lọc rỗng nên bị disable. Endpoint
  /// paged-advanced có projection đầy đủ và hỗ trợ lọc theo cột.
  @override
  Future<PaddyLotPage> searchLots({
    PaddyLotFilter filter = const PaddyLotFilter(),
    int start = 0,
    int length = 100,
  }) async {
    // Backend đọc bộ lọc từ `columns[i].search.value` theo `columns[i].data`.
    final columns = <Map<String, dynamic>>[
      _column('lotType', filter.lotType),
      _column('warehouseId', filter.warehouseId?.toString()),
      _column('statusId', filter.statusId?.toString()),
    ];

    final json = await _post('/api/v1/paddy-lots/paged-advanced', {
      'draw': 1,
      'start': start,
      'length': length,
      'columns': columns,
      'order': const <dynamic>[],
      'search': {'value': filter.keyword?.trim() ?? '', 'regex': false},
    });

    final resources = JsonReader.map(json, 'resources') ?? json;
    final rows = JsonReader.list(resources, 'data') ?? const <dynamic>[];
    final total = JsonReader.integer(resources, 'recordsFiltered') ??
        JsonReader.integer(resources, 'recordsTotal') ??
        rows.length;

    final lots = [
      for (final row in rows)
        if (row is Map<String, dynamic>) PaddyLotSummary.fromJson(row),
    ].where((lot) => lot.id > 0 && lot.lotCode.isNotEmpty).toList();

    return PaddyLotPage(lots: lots, totalRecords: total);
  }

  static Map<String, dynamic> _column(String data, String? search) => {
        'data': data,
        'name': data,
        'searchable': true,
        'orderable': false,
        'search': {'value': search ?? '', 'regex': false},
      };

  @override
  Future<List<PaddyLotFilterOption>> getWarehouseOptions() =>
      _options('/api/v1/warehouse');

  @override
  Future<List<PaddyLotFilterOption>> getStatusOptions() =>
      _options('/api/v1/lot-status');

  Future<List<PaddyLotFilterOption>> _options(String path) async {
    try {
      final json = await _get(path);
      final resources = JsonReader.value(json, 'resources');
      final rows = switch (resources) {
        List<dynamic> items => items,
        Map<String, dynamic> page => JsonReader.list(page, 'data') ??
            JsonReader.list(page, 'dataSource') ??
            const <dynamic>[],
        _ => const <dynamic>[],
      };
      final options = <PaddyLotFilterOption>[];
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final id = JsonReader.integer(row, 'id') ?? 0;
        final name = JsonReader.string(row, 'name');
        if (id > 0 && name != null && name.trim().isNotEmpty) {
          options.add(PaddyLotFilterOption(id: id, name: name.trim()));
        }
      }
      options.sort((a, b) => a.name.compareTo(b.name));
      return options;
    } on PaddyLotException {
      // Thiếu quyền đọc danh mục thì vẫn xem được danh sách lô, chỉ mất dropdown.
      return const [];
    }
  }

  @override
  Future<PaddyLotDetail> getLotDetail(int id) async {
    if (id <= 0) {
      throw const PaddyLotException('Mã lô không hợp lệ.');
    }
    final json = await _get('/api/v1/paddy-lots/$id');
    final resources = JsonReader.map(json, 'resources');
    if (resources == null) {
      throw const PaddyLotException('Backend không trả về chi tiết lô.');
    }
    return PaddyLotDetail.fromJson(resources);
  }

  @override
  Future<PaddyLotTraceability> getTraceabilityById(int id) async {
    if (id <= 0) throw const PaddyLotException('Mã lô không hợp lệ.');
    final json = await _get('/api/v1/paddy-lots/$id/traceability');
    return _traceability(json);
  }

  @override
  Future<PaddyLotTraceability> getTraceabilityByCode(String lotCode) async {
    final code = lotCode.trim();
    if (code.isEmpty) {
      throw const PaddyLotException('Mã lô không được để trống.');
    }
    final json = await _get(
      '/api/v1/paddy-lots/code/${Uri.encodeComponent(code)}/traceability',
    );
    return _traceability(json);
  }

  String get _token {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const PaddyLotException(
        'Bạn cần đăng nhập để xem thông tin lô.',
        statusCode: 401,
      );
    }
    return token;
  }

  Future<Map<String, dynamic>> _get(String path) =>
      _guard(() => _apiClient.get(path, token: _token));

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      _guard(() => _apiClient.post(path, token: _token, body: body));

  Future<Map<String, dynamic>> _guard(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      final json = await request();
      if (JsonReader.boolean(json, 'isSucceeded') == false) {
        throw PaddyLotException(
          JsonReader.string(json, 'message') ?? 'Không tải được dữ liệu lô.',
        );
      }
      return json;
    } on ApiException catch (error) {
      throw PaddyLotException(
        error.message,
        statusCode: error.statusCode,
        isTransient: error.isTransient,
      );
    }
  }

  PaddyLotTraceability _traceability(Map<String, dynamic> json) {
    final resources = JsonReader.map(json, 'resources');
    if (resources == null) {
      throw const PaddyLotException('Backend không trả về dữ liệu truy vết.');
    }
    return PaddyLotTraceability.fromJson(resources);
  }
}

class PaddyLotException implements Exception {
  const PaddyLotException(
    this.message, {
    this.statusCode,
    this.isTransient = false,
  });

  final String message;
  final int? statusCode;
  final bool isTransient;

  @override
  String toString() => message;
}
