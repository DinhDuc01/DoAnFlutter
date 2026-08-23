import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/quality_inspection.dart';

/// Truy cập API màn "Chất lượng & cách ly".
///
/// API đọc/cập nhật phiếu chất lượng dùng chung trên mobile.
abstract class QualityInspectionRepository {
  Future<QualityInspectionPage> loadPage({
    int page,
    int pageSize,
    String search,
    bool? passedInspection,
  });

  Future<QualityInspection> getDetail(int id);

  Future<List<QualityInspection>> getHistory(int paddyLotId);

  Future<QualityLot> getLot(int paddyLotId);

  /// Bản đồ lô để bảng hiện đúng "Loại hàng / Vị trí / Tổng tồn" như web.
  Future<Map<int, QualityLot>> loadLotMap();

  /// Lô lúa đang chờ kiểm định dùng riêng cho form tạo phiếu.
  Future<Map<int, QualityLot>> loadAwaitingPaddyLots() async {
    final lots = await loadLotMap();
    return {
      for (final entry in lots.entries)
        if (entry.value.isPaddy) entry.key: entry.value,
    };
  }

  Future<void> update(QualityInspectionUpdate payload);
}

/// Tách capability tạo phiếu để các fake repository read-only hiện có không bị
/// buộc phải triển khai mutation. Production repository hỗ trợ capability này.
abstract class QualityInspectionCreateRepository {
  Future<void> create(QualityInspectionCreate payload);
}

abstract class QualityInspectionBagRepository {
  Future<QualityInspectionBagProgress> getBagProgress(int inspectionId);

  Future<void> saveBagResult(
    int inspectionId,
    int bagId,
    SaveBagInspectionResult payload,
  );

  Future<void> completeBagInspection(int inspectionId, {String? note});

  Future<QualityMoistureConfig> getMoistureConfig();
}

class ApiQualityInspectionRepository
    implements
        QualityInspectionRepository,
        QualityInspectionBagRepository,
        QualityInspectionCreateRepository {
  ApiQualityInspectionRepository({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  /// Thứ tự cột phải khớp bản web để backend hiểu đúng lọc/sắp xếp.
  static const List<String> _columns = <String>[
    'lotCode',
    'inspectorName',
    'inspectedAt',
    'moisturePercent',
    'impurityPercent',
    'moldLevel',
    'pestLevel',
    'packagingStatus',
    'passedInspection',
    'handling',
    'id',
  ];

  static const int _sortColumn = 2; // inspectedAt
  static const int _passedColumn = 8;

  String get _token {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const QualityInspectionException(
        'Bạn cần đăng nhập để xem dữ liệu chất lượng.',
        statusCode: 401,
      );
    }
    return token;
  }

  @override
  Future<QualityInspectionPage> loadPage({
    int page = 1,
    int pageSize = 20,
    String search = '',
    bool? passedInspection,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final body = <String, dynamic>{
      'draw': safePage,
      'start': (safePage - 1) * pageSize,
      'length': pageSize,
      'search': {
        'value': search.trim(),
        'regex': false,
        'fixed': const <dynamic>[]
      },
      'columns': [
        for (var index = 0; index < _columns.length; index++)
          _column(
            _columns[index],
            index == _passedColumn && passedInspection != null
                ? '$passedInspection'
                : '',
          ),
      ],
      'order': [
        {'column': _sortColumn, 'dir': 'desc', 'name': 'inspectedAt'},
      ],
    };

    final json =
        await _post('/api/v1/quality-inspections/paged-advanced', body);
    final resources = JsonReader.map(json, 'resources') ?? json;
    final rows = JsonReader.list(resources, 'data') ??
        JsonReader.list(resources, 'dataSource') ??
        const <dynamic>[];
    return QualityInspectionPage(
      items: [
        for (final row in rows)
          if (row is Map<String, dynamic>) QualityInspection.fromJson(row),
      ],
      recordsTotal: JsonReader.integer(resources, 'recordsTotal') ?? 0,
      recordsFiltered: JsonReader.integer(resources, 'recordsFiltered') ??
          JsonReader.integer(resources, 'recordsTotal') ??
          0,
    );
  }

  @override
  Future<QualityInspection> getDetail(int id) async {
    final json = await _get('/api/v1/quality-inspections/$id');
    return QualityInspection.fromJson(_resourceMap(json));
  }

  @override
  Future<List<QualityInspection>> getHistory(int paddyLotId) async {
    final json = await _get('/api/v1/quality-inspections/by-lot/$paddyLotId');
    final value = JsonReader.value(json, 'resources');
    final rows = value is List ? value : const <dynamic>[];
    final items = [
      for (final row in rows)
        if (row is Map<String, dynamic>) QualityInspection.fromJson(row),
    ];
    items.sort(
      (a, b) => (b.inspectedAt ?? DateTime(0))
          .compareTo(a.inspectedAt ?? DateTime(0)),
    );
    return items;
  }

  @override
  Future<QualityLot> getLot(int paddyLotId) async {
    final json = await _get('/api/v1/paddy-lots/$paddyLotId');
    return QualityLot.fromJson(_resourceMap(json));
  }

  /// Nạp một lần danh sách lô (giống `lotsQuery` của web dùng pageSize 1000)
  /// để bảng phiếu kiểm định hiện được loại hàng, vị trí và tổng tồn của lô.
  @override
  Future<Map<int, QualityLot>> loadLotMap() async {
    final json = await _post('/api/v1/paddy-lots/paged-advanced', {
      'draw': 1,
      'start': 0,
      'length': 1000,
      'search': {'value': '', 'regex': false},
      'columns': [
        _column('lotType', ''),
        _column('warehouseId', ''),
        _column('statusId', ''),
      ],
      'order': const <dynamic>[],
    });
    final resources = JsonReader.map(json, 'resources') ?? json;
    final rows = JsonReader.list(resources, 'data') ??
        JsonReader.list(resources, 'dataSource') ??
        const <dynamic>[];
    final map = <int, QualityLot>{};
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final lot = QualityLot.fromJson(row);
      if (lot.id > 0) map[lot.id] = lot;
    }
    return map;
  }

  @override
  Future<Map<int, QualityLot>> loadAwaitingPaddyLots() async {
    final json = await _get('/api/v1/paddy-lots/awaiting-qc');
    final rows = JsonReader.value(json, 'resources');
    final map = <int, QualityLot>{};
    if (rows is! List) return map;
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final lot = QualityLot.fromJson(row);
      if (lot.id > 0 && lot.isPaddy) map[lot.id] = lot;
    }
    return map;
  }

  @override
  Future<void> update(QualityInspectionUpdate payload) async {
    await _put('/api/v1/quality-inspections', payload.toJson());
  }

  @override
  Future<void> create(QualityInspectionCreate payload) async {
    await _post('/api/v1/quality-inspections', payload.toJson());
  }

  @override
  Future<QualityInspectionBagProgress> getBagProgress(
    int inspectionId,
  ) async {
    final json = await _get('/api/v1/quality-inspections/$inspectionId/bags');
    return QualityInspectionBagProgress.fromJson(_resourceMap(json));
  }

  @override
  Future<void> saveBagResult(
    int inspectionId,
    int bagId,
    SaveBagInspectionResult payload,
  ) async {
    await _put(
      '/api/v1/quality-inspections/$inspectionId/bags/$bagId',
      payload.toJson(),
    );
  }

  @override
  Future<void> completeBagInspection(
    int inspectionId, {
    String? note,
  }) async {
    await _post('/api/v1/quality-inspections/$inspectionId/complete', {
      'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
    });
  }

  @override
  Future<QualityMoistureConfig> getMoistureConfig() async {
    final json = await _get('/api/v1/quality-inspections/config');
    return QualityMoistureConfig.fromJson(_resourceMap(json));
  }

  static Map<String, dynamic> _column(String data, String search) => {
        'data': data,
        'name': data,
        'searchable': true,
        'orderable': true,
        'search': {'value': search, 'regex': false, 'fixed': const <dynamic>[]},
      };

  Map<String, dynamic> _resourceMap(Map<String, dynamic> json) {
    final value = JsonReader.value(json, 'resources');
    return value is Map<String, dynamic> ? value : json;
  }

  Future<Map<String, dynamic>> _get(String path) =>
      _guard(() => _api.get(path, token: _token));

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      _guard(() => _api.post(path, token: _token, body: body));

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) =>
      _guard(() => _api.put(path, token: _token, body: body));

  Future<Map<String, dynamic>> _guard(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      final json = await request();
      if (JsonReader.boolean(json, 'isSucceeded') == false) {
        throw QualityInspectionException(
          JsonReader.string(json, 'message') ??
              'Không thực hiện được thao tác chất lượng.',
        );
      }
      return json;
    } on ApiException catch (error) {
      throw QualityInspectionException(
        error.message,
        statusCode: error.statusCode,
      );
    }
  }
}
