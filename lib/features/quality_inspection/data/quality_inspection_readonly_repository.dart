import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/quality_inspection_readonly.dart';

abstract class QualityInspectionReadOnlyRepository {
  Future<QualityInspectionPage> loadPage({
    required int start,
    required int length,
    String search,
    bool? passedInspection,
  });
  Future<QualityInspectionReadOnly> getDetail(int id);
  Future<List<QualityInspectionReadOnly>> getHistory(int paddyLotId);
  Future<QualityLotSummary> getLot(int paddyLotId);
}

class ApiQualityInspectionReadOnlyRepository
    implements QualityInspectionReadOnlyRepository {
  ApiQualityInspectionReadOnlyRepository({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();
  final ApiClient _api;

  String get _token {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const QualityInspectionReadOnlyException('Bạn cần đăng nhập để xem chất lượng.');
    }
    return token;
  }

  @override
  Future<QualityInspectionPage> loadPage({
    required int start,
    required int length,
    String search = '',
    bool? passedInspection,
  }) async {
    final body = <String, dynamic>{
      'draw': 1,
      'start': start,
      'length': length,
      'search': {'value': search, 'regex': false},
      'columns': <Map<String, dynamic>>[
        {'data': 'lotCode', 'name': 'lotCode', 'searchable': true, 'search': {'value': '', 'regex': false}},
        {'data': 'inspectorName', 'name': 'inspectorName', 'searchable': true, 'search': {'value': '', 'regex': false}},
        {'data': 'handling', 'name': 'handling', 'searchable': true, 'search': {'value': '', 'regex': false}},
        {
          'data': 'inspectedAt',
          'name': 'inspectedAt',
          'searchable': false,
        },
        {
          'data': 'passedInspection',
          'name': 'passedInspection',
          'searchable': false,
          'search': {'value': '', 'regex': false},
        },
      ],
      'order': const [
        {'column': 3, 'dir': 'desc'},
      ],
    };
    if (passedInspection != null) {
      (body['columns'] as List<dynamic>)[4]['search'] = {
        'value': '$passedInspection',
        'regex': false,
      };
    }
    final json = await _api.post(
      '/api/v1/quality-inspections/paged-advanced',
      token: _token,
      body: body,
    );
    _ensure(json);
    final resources = JsonReader.value(json, 'resources');
    final map = resources is Map<String, dynamic> ? resources : const <String, dynamic>{};
    final data = JsonReader.list(map, 'data') ??
        JsonReader.list(map, 'dataSource') ?? const <dynamic>[];
    return QualityInspectionPage(
      items: [for (final item in data) if (item is Map<String, dynamic>) _parse(item)],
      recordsTotal: JsonReader.integer(map, 'recordsTotal') ?? 0,
      recordsFiltered: JsonReader.integer(map, 'recordsFiltered') ?? 0,
    );
  }

  @override
  Future<QualityInspectionReadOnly> getDetail(int id) async {
    final json = await _api.get('/api/v1/quality-inspections/$id', token: _token);
    _ensure(json);
    return _parse(_resourceMap(json));
  }

  @override
  Future<List<QualityInspectionReadOnly>> getHistory(int paddyLotId) async {
    final json = await _api.get('/api/v1/quality-inspections/by-lot/$paddyLotId', token: _token);
    _ensure(json);
    final value = JsonReader.value(json, 'resources');
    final list = value is List ? value : const <dynamic>[];
    return [for (final item in list) if (item is Map<String, dynamic>) _parse(item)]
      ..sort((a, b) => (b.inspectedAt ?? DateTime(0)).compareTo(a.inspectedAt ?? DateTime(0)));
  }

  @override
  Future<QualityLotSummary> getLot(int paddyLotId) async {
    final json = await _api.get('/api/v1/paddy-lots/$paddyLotId', token: _token);
    _ensure(json);
    return QualityLotSummary(values: _resourceMap(json));
  }

  QualityInspectionReadOnly _parse(Map<String, dynamic> json) => QualityInspectionReadOnly(
        inspectionId: JsonReader.integer(json, 'id') ?? JsonReader.integer(json, 'inspectionId'),
        paddyLotId: JsonReader.integer(json, 'paddyLotId'),
        lotCode: JsonReader.string(json, 'lotCode'),
        lotStatusCode: JsonReader.string(json, 'lotStatusCode'),
        inspectorId: JsonReader.integer(json, 'inspectorId'),
        inspectorName: JsonReader.string(json, 'inspectorName'),
        inspectedAt: _date(json, 'inspectedAt'),
        moisturePercent: JsonReader.decimal(json, 'moisturePercent'),
        impurityPercent: JsonReader.decimal(json, 'impurityPercent'),
        moldLevel: JsonReader.string(json, 'moldLevel'),
        pestLevel: JsonReader.string(json, 'pestLevel'),
        packagingStatus: JsonReader.string(json, 'packagingStatus'),
        passedInspection: JsonReader.boolean(json, 'passedInspection'),
        handling: JsonReader.string(json, 'handling'),
        note: JsonReader.string(json, 'note'),
        affectedWeightKg: JsonReader.decimal(json, 'affectedWeightKg'),
        createdDate: _date(json, 'createdDate'),
        lastModifiedDate: _date(json, 'lastModifiedDate'),
      );

  DateTime? _date(Map<String, dynamic> json, String key) =>
      DateTime.tryParse(JsonReader.string(json, key) ?? '')?.toLocal();

  Map<String, dynamic> _resourceMap(Map<String, dynamic> json) {
    final value = JsonReader.value(json, 'resources');
    return value is Map<String, dynamic> ? value : json;
  }

  void _ensure(Map<String, dynamic> json) {
    if (JsonReader.boolean(json, 'isSucceeded') == false) {
      throw QualityInspectionReadOnlyException(
        JsonReader.string(json, 'message') ?? 'Không tải được dữ liệu chất lượng.',
      );
    }
  }
}

class QualityInspectionReadOnlyException implements Exception {
  const QualityInspectionReadOnlyException(this.message);
  final String message;
  @override
  String toString() => message;
}
