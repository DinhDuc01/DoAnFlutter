import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/outbound_order.dart';

/// Truy cập API phiếu xuất kho / giao hàng.
///
/// Vòng đời khớp backend: DRAFT → (allocate) PICKING → (pick) → (confirm-packing)
/// PACKED → (confirm-dispatch) DISPATCHED → (complete/fail-delivery).
abstract class OutboundOrderRepository {
  /// [statusId] được lọc phía backend nên `total` trả về luôn khớp bộ lọc —
  /// số trang không bị lệch khi đổi bộ lọc.
  Future<OutboundOrderPage> getPaged({
    String? keyword,
    int? statusId,
    int page = 1,
    int pageSize = 20,
  });

  Future<OutboundOrderDetail> getById(int id);

  Future<List<OutboundAllocationCandidate>> getAllocationCandidates(int id);

  Future<void> allocate(int id, List<AllocateItemPayload> allocations);

  Future<void> pick(int id, List<PickAllocationPayload> picks);

  Future<void> confirmPacking(
    int id, {
    required String qrCode,
    double? actualWeightKg,
    String? scaleDevice,
    List<PackingItemWeightPayload> items = const [],
  });

  Future<void> confirmDispatch(int id, {DateTime? dueDate, String? note});

  Future<CompleteDeliveryResult> completeDelivery(
    int id, {
    required String receiverName,
    required double paymentAmount,
    String? deliveryNote,
    String? proofImageUrl,
  });

  Future<void> failDelivery(int id, {required String reason});

  /// Hủy phiếu xuất kèm lý do.
  ///
  /// Backend nhận `reason` là tùy chọn (lưu vào cột `CancelReason`); ràng buộc
  /// bắt buộc nhập nằm ở phía client — mobile và web đều chặn lý do rỗng.
  Future<void> cancel(int id, {required String reason});

  /// Số dư công nợ phải thu của phiếu (dùng cho popup thu tiền khi giao hàng).
  Future<OutboundDebtSnapshot?> getReceivableSnapshot({
    required int outboundOrderId,
    required String soCode,
  });
}

/// Phân bổ lô cho một dòng phiếu xuất.
class AllocateItemPayload {
  const AllocateItemPayload({
    required this.outboundOrderItemId,
    required this.lots,
  });

  final int outboundOrderItemId;
  final List<AllocateLotPayload> lots;

  Map<String, dynamic> toJson() => {
        'outboundOrderItemId': outboundOrderItemId,
        'lots': [for (final lot in lots) lot.toJson()],
      };
}

class AllocateLotPayload {
  const AllocateLotPayload({
    required this.inventoryId,
    required this.quantityAllocated,
  });

  final int inventoryId;
  final double quantityAllocated;

  Map<String, dynamic> toJson() => {
        'inventoryId': inventoryId,
        'quantityAllocated': quantityAllocated,
      };
}

class PickAllocationPayload {
  const PickAllocationPayload({
    required this.allocationId,
    required this.quantityPicked,
  });

  final int allocationId;
  final double quantityPicked;

  Map<String, dynamic> toJson() => {
        'allocationId': allocationId,
        'quantityPicked': quantityPicked,
      };
}

/// Khối lượng đóng gói thực tế của một dòng phiếu xuất, kèm nguồn số liệu.
///
/// `source` để backend biết số này đến từ cân điện tử hay thủ kho gõ tay —
/// cần cho việc đối chiếu khi khách khiếu nại khối lượng.
class PackingItemWeightPayload {
  const PackingItemWeightPayload({
    required this.outboundOrderItemId,
    required this.actualWeightKg,
    required this.fromScale,
  });

  final int outboundOrderItemId;
  final double actualWeightKg;
  final bool fromScale;

  Map<String, dynamic> toJson() => {
        'outboundOrderItemId': outboundOrderItemId,
        'actualWeightKg': actualWeightKg,
        'source': fromScale ? 'SCALE' : 'MANUAL',
      };
}

class ApiOutboundOrderRepository implements OutboundOrderRepository {
  ApiOutboundOrderRepository({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  @override
  Future<OutboundOrderPage> getPaged({
    String? keyword,
    int? statusId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await _guard(() => _api.post(
          '/api/v1/outbound-orders/paged',
          token: _token,
          body: {
            'keyword': (keyword ?? '').trim().isEmpty ? null : keyword!.trim(),
            'outboundStatusId': (statusId ?? 0) > 0 ? statusId : null,
            'page': page < 1 ? 1 : page,
            'pageSize': pageSize,
          },
        ));

    final resources = JsonReader.map(json, 'resources');
    if (resources == null) {
      throw const OutboundOrderException(
        'Backend không trả về danh sách phiếu xuất.',
      );
    }
    final rows = JsonReader.list(resources, 'items') ?? const [];
    return OutboundOrderPage(
      total: JsonReader.integer(resources, 'total') ?? rows.length,
      items: [
        for (final row in rows)
          if (row is Map<String, dynamic>) OutboundOrderSummary.fromJson(row),
      ],
    );
  }

  @override
  Future<OutboundOrderDetail> getById(int id) async {
    if (id <= 0) throw const OutboundOrderException('Mã phiếu xuất không hợp lệ.');
    final json = await _guard(
      () => _api.get('/api/v1/outbound-orders/$id', token: _token),
    );
    final resources = JsonReader.map(json, 'resources');
    if (resources == null) {
      throw const OutboundOrderException(
        'Backend không trả về chi tiết phiếu xuất.',
      );
    }
    return OutboundOrderDetail.fromJson(resources);
  }

  @override
  Future<List<OutboundAllocationCandidate>> getAllocationCandidates(
    int id,
  ) async {
    final json = await _guard(
      () => _api.get(
        '/api/v1/outbound-orders/$id/allocation-candidates',
        token: _token,
      ),
    );
    final resources = JsonReader.value(json, 'resources');
    final rows = switch (resources) {
      List<dynamic> items => items,
      Map<String, dynamic> page =>
        JsonReader.list(page, 'items') ?? JsonReader.list(page, 'dataSource') ?? const [],
      _ => const <dynamic>[],
    };
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>)
          OutboundAllocationCandidate.fromJson(row),
    ];
  }

  @override
  Future<void> allocate(int id, List<AllocateItemPayload> allocations) async {
    if (allocations.isEmpty) {
      throw const OutboundOrderException(
        'Nhập số lượng phân bổ cho ít nhất một lô.',
      );
    }
    await _guard(() => _api.post(
          '/api/v1/outbound-orders/$id/allocate',
          token: _token,
          body: {
            'allocations': [for (final item in allocations) item.toJson()],
          },
        ));
  }

  @override
  Future<void> pick(int id, List<PickAllocationPayload> picks) async {
    if (picks.isEmpty) {
      throw const OutboundOrderException('Chưa có allocation nào để lấy hàng.');
    }
    await _guard(() => _api.post(
          '/api/v1/outbound-orders/$id/pick',
          token: _token,
          body: {'picks': [for (final pick in picks) pick.toJson()]},
        ));
  }

  @override
  Future<void> confirmPacking(
    int id, {
    required String qrCode,
    double? actualWeightKg,
    String? scaleDevice,
    List<PackingItemWeightPayload> items = const [],
  }) async {
    final code = qrCode.trim();
    if (code.isEmpty) {
      throw const OutboundOrderException('Mã QR đóng gói không được để trống.');
    }
    final device = scaleDevice?.trim();
    await _guard(() => _api.post(
          '/api/v1/outbound-orders/$id/confirm-packing',
          token: _token,
          body: {
            'qrCode': code,
            'actualWeightKg': actualWeightKg,
            'scaleDevice': device == null || device.isEmpty ? null : device,
            if (items.isNotEmpty)
              'items': [for (final item in items) item.toJson()],
          },
        ));
  }

  @override
  Future<void> confirmDispatch(
    int id, {
    DateTime? dueDate,
    String? note,
  }) async {
    await _guard(() => _api.post(
          '/api/v1/outbound-orders/$id/confirm-dispatch',
          token: _token,
          body: {
            'dueDate': dueDate?.toIso8601String(),
            'note': note?.trim().isEmpty == true ? null : note?.trim(),
          },
        ));
  }

  @override
  Future<CompleteDeliveryResult> completeDelivery(
    int id, {
    required String receiverName,
    required double paymentAmount,
    String? deliveryNote,
    String? proofImageUrl,
  }) async {
    final receiver = receiverName.trim();
    if (receiver.isEmpty) {
      throw const OutboundOrderException('Vui lòng nhập tên người nhận.');
    }
    if (paymentAmount < 0) {
      throw const OutboundOrderException(
        'Số tiền khách thanh toán thêm không được âm.',
      );
    }
    final json = await _guard(() => _api.post(
          '/api/v1/outbound-orders/$id/complete-delivery',
          token: _token,
          body: {
            'receiverName': receiver,
            'paymentAmount': paymentAmount,
            'deliveryNote': deliveryNote?.trim().isEmpty == true
                ? null
                : deliveryNote?.trim(),
            'proofImageUrl': proofImageUrl,
          },
        ));
    final resources = JsonReader.map(json, 'resources');
    return resources == null
        ? CompleteDeliveryResult(paymentAmount: paymentAmount)
        : CompleteDeliveryResult.fromJson(resources);
  }

  @override
  Future<void> failDelivery(int id, {required String reason}) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw const OutboundOrderException('Vui lòng nhập lý do giao thất bại.');
    }
    await _guard(() => _api.post(
          '/api/v1/outbound-orders/$id/fail-delivery',
          token: _token,
          body: {'reason': trimmed},
        ));
  }

  @override
  Future<void> cancel(int id, {required String reason}) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw const OutboundOrderException('Vui lòng nhập lý do hủy phiếu xuất.');
    }
    await _guard(() => _api.post(
          '/api/v1/outbound-orders/$id/cancel',
          token: _token,
          body: {'reason': trimmed},
        ));
  }

  @override
  Future<OutboundDebtSnapshot?> getReceivableSnapshot({
    required int outboundOrderId,
    required String soCode,
  }) async {
    try {
      // Dùng đúng endpoint mà màn Công nợ của mobile đang gọi; lọc theo mã đơn
      // rồi khớp chính xác refType/refId như web.
      final json = await _api.post(
        '/api/v1/party-debts/documents/paged',
        token: _token,
        body: {
          'draw': 1,
          'start': 0,
          'length': 50,
          'search': {'value': soCode, 'regex': false},
          'columns': <dynamic>[],
          'order': <dynamic>[],
          'direction': 'RECEIVABLE',
          'overdueOnly': false,
        },
      );
      final resources = JsonReader.map(json, 'resources');
      final rows = resources == null
          ? const <dynamic>[]
          : JsonReader.list(resources, 'data') ??
              JsonReader.list(resources, 'dataSource') ??
              const <dynamic>[];
      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;
        final refType = (JsonReader.string(row, 'refType') ?? '').toUpperCase();
        final refId = JsonReader.integer(row, 'refId') ?? 0;
        if (refType != 'OUTBOUND_ORDER' || refId != outboundOrderId) continue;
        final total = JsonReader.decimal(row, 'totalAmount') ?? 0;
        final outstanding = JsonReader.decimal(row, 'outstandingAmount') ?? 0;
        return OutboundDebtSnapshot(
          totalAmount: total,
          paidAmount: JsonReader.decimal(row, 'paidAmount') ?? (total - outstanding),
          outstandingAmount: outstanding,
        );
      }
      return null;
    } catch (_) {
      // Không lấy được công nợ không nên chặn luồng giao hàng — backend vẫn
      // kiểm tra lại khi lưu.
      return null;
    }
  }

  String get _token {
    final value = AuthSessionStore.current?.accessToken;
    if (value == null || value.isEmpty) {
      throw const OutboundOrderException(
        'Bạn cần đăng nhập để xem phiếu xuất.',
        statusCode: 401,
      );
    }
    return value;
  }

  Future<Map<String, dynamic>> _guard(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      final json = await request();
      if (JsonReader.boolean(json, 'isSucceeded') == false) {
        throw OutboundOrderException(
          JsonReader.string(json, 'message') ?? 'Thao tác không thành công.',
        );
      }
      return json;
    } on ApiException catch (error) {
      throw OutboundOrderException(
        error.message,
        statusCode: error.statusCode,
        isTransient: error.isTransient,
      );
    }
  }
}

class OutboundOrderException implements Exception {
  const OutboundOrderException(
    this.message, {
    this.statusCode,
    this.isTransient = false,
  });

  final String message;
  final int? statusCode;
  final bool isTransient;

  /// 422 = dữ liệu không hợp lệ về nghiệp vụ (vượt dư nợ, đã thu đủ…) — UI nên
  /// giữ form mở để người dùng sửa, giống cách web xử lý.
  bool get isValidation => statusCode == 422;

  @override
  String toString() => message;
}
