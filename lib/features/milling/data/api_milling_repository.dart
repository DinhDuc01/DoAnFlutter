import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/milling_order.dart';
import 'milling_repository.dart';

class ApiMillingRepository implements MillingRepository {
  ApiMillingRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

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
    final inputs = JsonReader.list(detail, 'inputs') ?? const [];
    final firstInput =
        inputs.cast<Object?>().whereType<Map<String, dynamic>>().firstOrNull;
    return MillingOrder(
      id: id,
      millingCode: JsonReader.string(detail, 'millingCode') ?? 'MO-$id',
      inputLotCode: firstInput == null
          ? 'Lô chưa xác định'
          : JsonReader.string(firstInput, 'lotCode') ?? 'Lô chưa xác định',
      inputWeightKg: JsonReader.decimal(detail, 'computedPaddyKg') ?? 0,
      warehouseZone:
          JsonReader.string(detail, 'warehouseName') ?? 'Kho chưa xác định',
      locationCode: firstInput == null
          ? 'Chưa có vị trí'
          : '${JsonReader.integer(firstInput, 'locationId') ?? 'N/A'}',
      scaleCode: JsonReader.string(detail, 'machineRef') ?? 'Cân thủ công',
      // The backend returns output totals, not individual BLE readings.
      // Do not invent bag records; each bag is captured from the scale.
      riceBags: const [],
      branBags: const [],
    );
  }

  @override
  Future<void> saveRiceBags(MillingOrder order) async {}

  @override
  Future<void> saveBranBags(MillingOrder order) async {}

  @override
  Future<void> completeOrder(MillingOrder order) async {
    final json = await _apiClient.post(
      '/api/v1/milling-orders/${order.id}/complete',
      token: _currentToken(),
    );
    if (JsonReader.boolean(json, 'isSucceeded') != true) {
      throw MillingApiException(
        JsonReader.string(json, 'message') ?? 'Không hoàn thành được lệnh xay',
      );
    }
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
