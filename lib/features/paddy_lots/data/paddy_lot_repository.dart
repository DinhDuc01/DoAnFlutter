import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/paddy_lot.dart';

abstract class PaddyLotRepository {
  Future<List<PaddyLotSummary>> getLots();
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

  Future<Map<String, dynamic>> _get(String path) async {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const PaddyLotException(
        'Bạn cần đăng nhập để xem thông tin lô.',
        statusCode: 401,
      );
    }
    try {
      final json = await _apiClient.get(path, token: token);
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
