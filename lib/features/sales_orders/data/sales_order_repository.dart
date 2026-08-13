import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/sales_order.dart';

/// Truy cập API đơn bán. Mobile dùng `POST /sales-orders/paged` (API lọc dành
/// cho mobile); web dùng `paged-advanced`.
abstract class SalesOrderRepository {
  /// [statusId] và [channel] được lọc phía backend nên `total` trả về luôn khớp
  /// bộ lọc — số trang không bị lệch khi đổi bộ lọc.
  Future<SalesOrderPage> getPaged({
    String? keyword,
    int? statusId,
    String? channel,
    int page = 1,
    int pageSize = 20,
  });

  Future<SalesOrderDetail> getById(int id);

  /// Hủy đơn bán kèm lý do (backend lưu vào cột `CancelReason`).
  Future<void> cancel(int id, {required String reason});

  /// Tạo phiếu xuất (OutboundOrder DRAFT) từ đơn bán. Trả về id phiếu xuất.
  Future<int> createOutbound(int id, List<CreateOutboundLine> items);
}

/// Một dòng hàng cần xuất khi tạo phiếu xuất từ đơn bán.
class CreateOutboundLine {
  const CreateOutboundLine({
    required this.productVariantId,
    required this.quantityToDispatch,
  });

  final int productVariantId;
  final double quantityToDispatch;

  Map<String, dynamic> toJson() => {
        'productVariantId': productVariantId,
        'quantityToDispatch': quantityToDispatch,
      };
}

class ApiSalesOrderRepository implements SalesOrderRepository {
  ApiSalesOrderRepository({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  @override
  Future<SalesOrderPage> getPaged({
    String? keyword,
    int? statusId,
    String? channel,
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await _guard(() => _api.post(
          '/api/v1/sales-orders/paged',
          token: _token,
          body: {
            'keyword': (keyword ?? '').trim().isEmpty ? null : keyword!.trim(),
            'statusId': (statusId ?? 0) > 0 ? statusId : null,
            'channel':
                (channel ?? '').trim().isEmpty ? null : channel!.trim().toUpperCase(),
            'page': page < 1 ? 1 : page,
            'pageSize': pageSize,
          },
        ));

    final resources = JsonReader.map(json, 'resources');
    if (resources == null) {
      throw const SalesOrderException('Backend không trả về danh sách đơn bán.');
    }
    final rows = JsonReader.list(resources, 'items') ?? const [];
    return SalesOrderPage(
      total: JsonReader.integer(resources, 'total') ?? rows.length,
      items: [
        for (final row in rows)
          if (row is Map<String, dynamic>) SalesOrderSummary.fromJson(row),
      ],
    );
  }

  @override
  Future<SalesOrderDetail> getById(int id) async {
    if (id <= 0) throw const SalesOrderException('Mã đơn bán không hợp lệ.');
    final json = await _guard(
      () => _api.get('/api/v1/sales-orders/$id', token: _token),
    );
    final resources = JsonReader.map(json, 'resources');
    if (resources == null) {
      throw const SalesOrderException('Backend không trả về chi tiết đơn bán.');
    }
    return SalesOrderDetail.fromJson(resources);
  }

  @override
  Future<void> cancel(int id, {required String reason}) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw const SalesOrderException('Vui lòng nhập lý do hủy đơn.');
    }
    await _guard(() => _api.post(
          '/api/v1/sales-orders/$id/cancel',
          token: _token,
          body: {'reason': trimmed},
        ));
  }

  @override
  Future<int> createOutbound(int id, List<CreateOutboundLine> items) async {
    if (items.isEmpty) {
      throw const SalesOrderException(
        'Cần ít nhất một dòng hàng có số lượng xuất lớn hơn 0.',
      );
    }
    final json = await _guard(() => _api.post(
          '/api/v1/sales-orders/$id/create-outbound',
          token: _token,
          body: {'items': [for (final item in items) item.toJson()]},
        ));
    final resources = JsonReader.map(json, 'resources');
    return resources == null
        ? 0
        : JsonReader.integer(resources, 'outboundOrderId') ?? 0;
  }

  String get _token {
    final value = AuthSessionStore.current?.accessToken;
    if (value == null || value.isEmpty) {
      throw const SalesOrderException(
        'Bạn cần đăng nhập để xem đơn bán.',
        statusCode: 401,
      );
    }
    return value;
  }

  /// Gọi API và quy đổi lỗi về [SalesOrderException] để UI hiển thị thống nhất.
  Future<Map<String, dynamic>> _guard(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      final json = await request();
      if (JsonReader.boolean(json, 'isSucceeded') == false) {
        throw SalesOrderException(
          JsonReader.string(json, 'message') ?? 'Thao tác không thành công.',
        );
      }
      return json;
    } on ApiException catch (error) {
      throw SalesOrderException(
        error.message,
        statusCode: error.statusCode,
        isTransient: error.isTransient,
      );
    }
  }
}

class SalesOrderException implements Exception {
  const SalesOrderException(
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
