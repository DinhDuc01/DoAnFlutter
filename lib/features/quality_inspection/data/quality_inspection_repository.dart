import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/quality_inspection.dart';

abstract class QualityInspectionRepository {
  Future<List<QualityInspection>> getInspections();
  Future<List<PaddyLotOption>> getPaddyLots();
  Future<int> createInspection(QualityInspectionDraft draft);
}

class ApiQualityInspectionRepository implements QualityInspectionRepository {
  ApiQualityInspectionRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<List<QualityInspection>> getInspections() async {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const QualityInspectionException(
        'Bạn cần đăng nhập để xem phiếu kiểm chất.',
      );
    }
    try {
      final response = await _apiClient.get(
        '/api/v1/quality-inspections',
        token: token,
      );
      _ensureSucceeded(response, 'Không tải được phiếu kiểm chất.');
      final data = _resourceList(response);
      return [
        for (final item in data)
          if (item is Map<String, dynamic>) _fromJson(item),
      ]..sort((a, b) => b.inspectedAt.compareTo(a.inspectedAt));
    } on ApiException catch (error) {
      throw QualityInspectionException(error.message);
    }
  }

  @override
  Future<List<PaddyLotOption>> getPaddyLots() async {
    final token = _token();
    try {
      final response = await _apiClient.get('/api/v1/paddy-lots', token: token);
      _ensureSucceeded(response, 'Không tải được danh sách lô lúa/gạo.');
      final data = _resourceList(response);
      return [
        for (final item in data)
          if (item is Map<String, dynamic> && _isInspectableLot(item))
            PaddyLotOption(
              id: JsonReader.integer(item, 'id') ?? 0,
              code: JsonReader.string(item, 'lotCode') ??
                  'Lô #${JsonReader.integer(item, 'id') ?? 0}',
              lotType: JsonReader.string(item, 'lotType'),
              remainingWeightKg:
                  JsonReader.decimal(item, 'remainingWeightKg') ?? 0,
            ),
      ].where((lot) => lot.id > 0).toList()
        ..sort((a, b) => b.id.compareTo(a.id));
    } on ApiException catch (error) {
      throw QualityInspectionException(error.message);
    }
  }

  @override
  Future<int> createInspection(QualityInspectionDraft draft) async {
    _validateDraft(draft);
    try {
      final response = await _apiClient.post(
        '/api/v1/quality-inspections',
        token: _token(),
        body: {
          'paddyLotId': draft.paddyLotId,
          'inspectedAt': DateTime.now().toUtc().toIso8601String(),
          'moisturePercent': draft.moisturePercent,
          'impurityPercent': draft.impurityPercent,
          'moldLevel': draft.moldLevel,
          'pestLevel': draft.pestLevel,
          'packagingStatus': draft.packagingStatus,
          'passedInspection': draft.passed,
          'handling': draft.handling,
          'note': draft.note,
        },
      );
      _ensureSucceeded(response, 'Không tạo được phiếu kiểm chất.');
      final resources = JsonReader.value(response, 'resources');
      final id = switch (resources) {
        num value => value.toInt(),
        Map<String, dynamic> value => JsonReader.integer(value, 'id') ?? 0,
        _ => 0,
      };
      if (id <= 0) {
        throw const QualityInspectionException(
          'Backend không trả về mã phiếu kiểm chất vừa tạo.',
        );
      }
      return id;
    } on ApiException catch (error) {
      throw QualityInspectionException(error.message);
    }
  }

  String _token() {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const QualityInspectionException('Bạn cần đăng nhập để kiểm chất.');
    }
    return token;
  }

  QualityInspection _fromJson(Map<String, dynamic> json) {
    return QualityInspection(
      id: JsonReader.integer(json, 'id') ?? 0,
      paddyLotId: JsonReader.integer(json, 'paddyLotId') ?? 0,
      lotCode: JsonReader.string(json, 'lotCode') ?? 'Lô chưa xác định',
      inspectorName: JsonReader.string(json, 'inspectorName'),
      inspectedAt:
          DateTime.tryParse(JsonReader.string(json, 'inspectedAt') ?? '')
                  ?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      moisturePercent: JsonReader.decimal(json, 'moisturePercent'),
      impurityPercent: JsonReader.decimal(json, 'impurityPercent'),
      moldLevel: JsonReader.string(json, 'moldLevel'),
      pestLevel: JsonReader.string(json, 'pestLevel'),
      packagingStatus: JsonReader.string(json, 'packagingStatus'),
      passed: JsonReader.boolean(json, 'passedInspection') ?? false,
      handling: JsonReader.string(json, 'handling'),
      note: JsonReader.string(json, 'note'),
    );
  }

  List<dynamic> _resourceList(Map<String, dynamic> response) {
    final resources = JsonReader.value(response, 'resources');
    return switch (resources) {
      List<dynamic> items => items,
      Map<String, dynamic> page => JsonReader.list(page, 'dataSource') ??
          JsonReader.list(page, 'items') ??
          const <dynamic>[],
      _ => const <dynamic>[],
    };
  }

  void _ensureSucceeded(Map<String, dynamic> response, String fallback) {
    if (JsonReader.boolean(response, 'isSucceeded') == false) {
      throw QualityInspectionException(
        JsonReader.string(response, 'message') ?? fallback,
      );
    }
  }

  bool _isInspectableLot(Map<String, dynamic> json) {
    final type = JsonReader.string(json, 'lotType')?.toUpperCase();
    return type == null || type == 'PADDY' || type == 'RICE';
  }

  void _validateDraft(QualityInspectionDraft draft) {
    if (draft.paddyLotId <= 0) {
      throw const QualityInspectionException('Lô lúa/gạo không hợp lệ.');
    }
    for (final entry in {
      'Độ ẩm': draft.moisturePercent,
      'Tạp chất': draft.impurityPercent,
    }.entries) {
      final value = entry.value;
      if (value == null) {
        throw QualityInspectionException('${entry.key} không được để trống.');
      }
      if (value < 0 || value > 100) {
        throw QualityInspectionException(
          '${entry.key} phải nằm trong khoảng từ 0 đến 100%.',
        );
      }
    }
  }
}

class PaddyLotOption {
  const PaddyLotOption({
    required this.id,
    required this.code,
    this.lotType,
    this.remainingWeightKg = 0,
  });

  final int id;
  final String code;
  final String? lotType;
  final double remainingWeightKg;

  String get label {
    final typeLabel = lotType?.toUpperCase() == 'RICE' ? 'Gạo' : 'Lúa';
    return '$code · $typeLabel · ${remainingWeightKg.toStringAsFixed(0)} kg';
  }
}

class QualityInspectionDraft {
  const QualityInspectionDraft({
    required this.paddyLotId,
    required this.passed,
    this.moisturePercent,
    this.impurityPercent,
    this.moldLevel,
    this.pestLevel,
    this.packagingStatus,
    this.handling,
    this.note,
  });
  final int paddyLotId;
  final bool passed;
  final double? moisturePercent;
  final double? impurityPercent;
  final String? moldLevel;
  final String? pestLevel;
  final String? packagingStatus;
  final String? handling;
  final String? note;
}

class QualityInspectionException implements Exception {
  const QualityInspectionException(this.message);

  final String message;

  @override
  String toString() => message;
}
