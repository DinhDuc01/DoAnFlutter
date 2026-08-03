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
    final resourcesValue = JsonReader.value(json, 'resources');
    final resources = switch (resourcesValue) {
      List<dynamic> items => items,
      Map<String, dynamic> page => JsonReader.list(page, 'dataSource') ??
          JsonReader.list(page, 'items') ??
          const <dynamic>[],
      _ => const <dynamic>[],
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

  /// Enriches a schedule with farmer contact information for the detail screen.
  Future<PurchaseSchedule> getScheduleDetails(
    PurchaseSchedule schedule,
  ) async {
    if (schedule.farmerId <= 0) return schedule;

    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiException(
        message: 'Bạn cần đăng nhập để xem chi tiết lịch thu mua.',
      );
    }

    final json = await _apiClient.get(
      '/api/v1/farmers/${schedule.farmerId}',
      token: token,
    );
    final farmer = JsonReader.map(json, 'resources');
    if (farmer == null) return schedule;

    return schedule.copyWith(
      farmerName: JsonReader.string(farmer, 'name'),
      farmerPhone: JsonReader.string(farmer, 'phone'),
      farmerAddress: JsonReader.string(farmer, 'address'),
    );
  }
}
