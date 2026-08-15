import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/inbound_order.dart';

/// Truy cập API màn "Nhập kho & xếp vị trí".
///
/// Nối đúng các API mà bản web dùng, trừ `POST /{id}/approve` và
/// `POST /{id}/reject`: PHÊ DUYỆT phiếu nhập chỉ làm trên web. Mobile chỉ được
/// GỬI DUYỆT và NHẬN HÀNG.
abstract class InboundOrderRepository {
  Future<List<InboundPutawayLine>> getPutawayPending();

  Future<List<StorageLocation>> getLocations();

  Future<void> submit(int orderId);

  Future<void> startReceipt(int orderId, int itemId);

  Future<void> recordQuantity(int orderId, int itemId, double quantityReceived);

  Future<List<PutawaySuggestion>> getPutawaySuggestions(int orderId, int itemId);

  Future<BagPutawayPlan?> getBagPutawayPlan(int orderId, int itemId);

  Future<void> selectPutaway(
    int orderId,
    int itemId, {
    required int locationId,
    required bool isOverride,
    String? overrideReason,
    double? weightKg,
  });

  Future<void> confirmReceipt(
    int orderId,
    int itemId, {
    required String operationKey,
    List<BagPutawayColumn>? columns,
  });
}

class ApiInboundOrderRepository implements InboundOrderRepository {
  ApiInboundOrderRepository({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  String get _token {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const InboundOrderException(
        'Bạn cần đăng nhập để xử lý nhập kho.',
        statusCode: 401,
      );
    }
    return token;
  }

  /// 1 request gộp: backend trả sẵn phiếu lúa/gạo chờ xếp kho kèm dòng hàng đã
  /// hydrate (thay cho list + N lần getById gây N+1) — giống web.
  @override
  Future<List<InboundPutawayLine>> getPutawayPending() async {
    final json = await _get('/api/v1/inbound-orders/putaway-pending');
    final value = JsonReader.value(json, 'resources');
    final rows = value is List ? value : const <dynamic>[];
    final lines = <InboundPutawayLine>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final order = InboundOrder.fromJson(row);
      for (final item in order.items) {
        final line = InboundPutawayLine(order: order, item: item);
        if (_isPaddyLine(line)) lines.add(line);
      }
    }
    return lines;
  }

  @override
  Future<List<StorageLocation>> getLocations() async {
    try {
      final json = await _get('/api/v1/location');
      final value = JsonReader.value(json, 'resources');
      final rows = switch (value) {
        List<dynamic> items => items,
        Map<String, dynamic> page => JsonReader.list(page, 'data') ??
            JsonReader.list(page, 'dataSource') ??
            const <dynamic>[],
        _ => const <dynamic>[],
      };
      return [
        for (final row in rows)
          if (row is Map<String, dynamic>) StorageLocation.fromJson(row),
      ];
    } on InboundOrderException {
      // Thiếu quyền đọc danh mục vị trí thì vẫn dùng được gợi ý của backend.
      return const <StorageLocation>[];
    }
  }

  @override
  Future<void> submit(int orderId) =>
      _post('/api/v1/inbound-orders/$orderId/submit', const <String, dynamic>{});

  @override
  Future<void> startReceipt(int orderId, int itemId) => _post(
        '/api/v1/inbound-orders/$orderId/receipts/start',
        {'inboundOrderItemId': itemId},
      );

  @override
  Future<void> recordQuantity(
    int orderId,
    int itemId,
    double quantityReceived,
  ) =>
      _post(
        '/api/v1/inbound-orders/$orderId/receipts/$itemId/record-quantity',
        {'quantityReceived': quantityReceived, 'note': null},
      );

  @override
  Future<List<PutawaySuggestion>> getPutawaySuggestions(
    int orderId,
    int itemId,
  ) async {
    final json = await _get(
      '/api/v1/inbound-orders/$orderId/receipts/$itemId/putaway-suggestions',
    );
    final value = JsonReader.value(json, 'resources');
    final rows = value is List ? value : const <dynamic>[];
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) PutawaySuggestion.fromJson(row),
    ];
  }

  @override
  Future<BagPutawayPlan?> getBagPutawayPlan(int orderId, int itemId) async {
    try {
      final json = await _get(
        '/api/v1/inbound-orders/$orderId/receipts/$itemId/bag-putaway-plan',
      );
      final resources = JsonReader.map(json, 'resources');
      if (resources == null) return null;
      final plan = BagPutawayPlan.fromJson(resources);
      return plan.columns.isEmpty && plan.candidateLocations.isEmpty ? null : plan;
    } catch (_) {
      // Phiếu không quản lý theo bao thì backend không có phương án xếp bao.
      return null;
    }
  }

  @override
  Future<void> selectPutaway(
    int orderId,
    int itemId, {
    required int locationId,
    required bool isOverride,
    String? overrideReason,
    double? weightKg,
  }) =>
      _post(
        '/api/v1/inbound-orders/$orderId/receipts/$itemId/select-putaway',
        {
          'locationId': locationId,
          'isOverride': isOverride,
          'overrideReason': overrideReason,
          'weightKg': weightKg,
        },
      );

  @override
  Future<void> confirmReceipt(
    int orderId,
    int itemId, {
    required String operationKey,
    List<BagPutawayColumn>? columns,
  }) =>
      _post(
        '/api/v1/inbound-orders/$orderId/receipts/$itemId/confirm',
        {
          'operationKey': operationKey,
          'columns': (columns == null || columns.isEmpty)
              ? null
              : [
                  for (final column in columns)
                    {'locationId': column.locationId, 'bagIds': column.bagIds},
                ],
        },
      );

  /// Màn này chỉ xử lý lúa/gạo — cùng bộ điều kiện với `isPaddyLine` của web.
  bool _isPaddyLine(InboundPutawayLine line) {
    final sourceType = line.order.sourceType?.trim().toUpperCase();
    if (sourceType == 'RECEIPT' || sourceType == 'PADDY_PURCHASE') return true;
    if (line.order.paddyPurchaseReceiptId != null ||
        (line.order.paddyPurchaseReceiptCode ?? '').isNotEmpty ||
        line.item.paddyLotId != null ||
        (line.item.paddyLotCode ?? '').isNotEmpty) {
      return true;
    }
    final text = [
      line.order.note,
      line.item.productVariantName,
      line.item.sku,
    ].whereType<String>().join(' ');
    return RegExp(r'(lúa|lua|thóc|thoc|gạo|gao|paddy|rice)', caseSensitive: false)
        .hasMatch(text);
  }

  Future<Map<String, dynamic>> _get(String path) =>
      _guard(() => _api.get(path, token: _token));

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      _guard(() => _api.post(path, token: _token, body: body));

  Future<Map<String, dynamic>> _guard(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      final json = await request();
      if (JsonReader.boolean(json, 'isSucceeded') == false) {
        throw InboundOrderException(
          JsonReader.string(json, 'message') ??
              'Không thực hiện được thao tác nhập kho.',
        );
      }
      return json;
    } on ApiException catch (error) {
      throw InboundOrderException(error.message, statusCode: error.statusCode);
    }
  }
}
