import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/purchase_schedule.dart';

class PurchaseScheduleRepository {
  PurchaseScheduleRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<PurchaseSchedule>> getSchedules() async {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiException(
          message: 'Bạn cần đăng nhập để xem lịch thu mua.');
    }

    final json = await _apiClient.get(
      '/api/v1/paddy-purchase-schedules',
      token: token,
    );
    if (JsonReader.boolean(json, 'isSucceeded') == false) {
      throw ApiException(
        message: JsonReader.string(json, 'message') ??
            'Không tải được lịch thu mua.',
      );
    }

    // Backend supports both a plain resource list and a paginated result.
    final resourcesValue =
        JsonReader.value(json, 'resources') ?? JsonReader.value(json, 'data');
    final resources = switch (resourcesValue) {
      List<dynamic> items => items,
      Map<String, dynamic> page => JsonReader.list(page, 'dataSource') ??
          JsonReader.list(page, 'items') ??
          JsonReader.list(page, 'data') ??
          JsonReader.list(page, 'results') ??
          JsonReader.list(page, 'resources') ??
          const <dynamic>[],
      _ => JsonReader.list(json, 'dataSource') ??
          JsonReader.list(json, 'items') ??
          JsonReader.list(json, 'results') ??
          const <dynamic>[],
    };
    final schedules = [
      for (final item in resources)
        if (item is Map<String, dynamic>) PurchaseSchedule.fromJson(item),
    ];
    // The purchase history is presented newest first for field operators.
    schedules.sort((a, b) {
      final date = b.scheduledAt.compareTo(a.scheduledAt);
      return date != 0 ? date : b.id.compareTo(a.id);
    });
    return schedules;
  }

  /// Enriches a schedule with fresh server data (giống lúa, kho, tình trạng lập phiếu)
  /// and farmer contact information for the detail screen.
  Future<PurchaseSchedule> getScheduleDetails(
    PurchaseSchedule schedule,
  ) async {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiException(
        message: 'Bạn cần đăng nhập để xem chi tiết lịch thu mua.',
      );
    }

    var result = schedule;

    // Lấy bản mới nhất của lịch: có riceVarietyName, warehouseName và cờ canCreateReceipt.
    if (schedule.id > 0) {
      try {
        final json = await _apiClient.get(
          '/api/v1/paddy-purchase-schedules/${schedule.id}',
          token: token,
        );
        final detail = JsonReader.map(json, 'resources');
        if (detail != null) {
          final fresh = PurchaseSchedule.fromJson(detail);
          result = result.copyWith(
            riceVariety: fresh.riceVariety,
            riceVarietyId: fresh.riceVarietyId,
            warehouseId: fresh.warehouseId,
            warehouseName: fresh.warehouseName,
            statusId: fresh.statusId,
            statusCode: fresh.statusCode,
            status: fresh.status,
            estimatedWeightKg: fresh.estimatedWeightKg,
            location: fresh.location,
            expectedPrice: fresh.expectedPrice,
            note: fresh.note,
            receiptCount: fresh.receiptCount,
            receiptedWeightKg: fresh.receiptedWeightKg,
            remainingQtyKg: fresh.remainingQtyKg,
            canCreateReceiptFlag: fresh.canCreateReceiptFlag,
          );
        }
      } on ApiException {
        // Giữ dữ liệu từ danh sách nếu API chi tiết không khả dụng.
      }
    }

    if (schedule.farmerId <= 0) return result;

    try {
      // Farmer contact is optional enrichment. The schedule detail itself is
      // authorized by RICE_PURCHASE + READ, while this endpoint separately
      // requires FARMERS + READ. A read-only warehouse user may legitimately
      // have the former without the latter.
      final json = await _apiClient.get(
        '/api/v1/farmers/${schedule.farmerId}',
        token: token,
      );
      final farmer = JsonReader.map(json, 'resources');
      if (farmer == null) return result;

      return result.copyWith(
        farmerName: JsonReader.string(farmer, 'name'),
        farmerPhone: JsonReader.string(farmer, 'phone'),
        farmerAddress: JsonReader.string(farmer, 'address'),
      );
    } on ApiException {
      // Keep authorized schedule data when optional FARMERS enrichment is
      // forbidden or unavailable instead of breaking the whole detail screen.
      return result;
    }
  }
}
