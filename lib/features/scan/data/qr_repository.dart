import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/resolved_qr.dart';

abstract class QrRepository {
  Future<ResolvedQr> resolve(
    String payload, {
    String operation = 'LOOKUP',
    int? referenceId,
    int? warehouseId,
  });
}

class ApiQrRepository implements QrRepository {
  ApiQrRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<ResolvedQr> resolve(
    String payload, {
    String operation = 'LOOKUP',
    int? referenceId,
    int? warehouseId,
  }) async {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiException(message: 'Bạn cần đăng nhập để tra cứu mã QR.');
    }

    final json = await _apiClient.post(
      '/api/v1/qr/resolve',
      token: token,
      body: {
        'payload': payload,
        'context': {
          'operation': operation,
          'referenceId': referenceId,
          'warehouseId': warehouseId,
        },
      },
    );
    if (JsonReader.boolean(json, 'isSucceeded') == false) {
      throw ApiException(
        message: JsonReader.string(json, 'message') ?? 'Mã QR không hợp lệ.',
      );
    }

    final resources = JsonReader.map(json, 'resources');
    if (resources == null) {
      throw const ApiException(message: 'API không trả thông tin mã QR.');
    }
    final validation = JsonReader.map(resources, 'validationResult');
    if (validation != null &&
        JsonReader.boolean(validation, 'success') == false) {
      throw ApiException(
        message: JsonReader.string(validation, 'errorMessage') ??
            'Mã QR không phù hợp với thao tác hiện tại.',
      );
    }
    return ResolvedQr.fromJson(resources);
  }
}
