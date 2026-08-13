import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/inventory_stock.dart';

class InventoryStockException implements Exception {
  const InventoryStockException(this.message, {this.isTransient = false});

  final String message;
  final bool isTransient;

  @override
  String toString() => message;
}

/// Bộ lọc của màn Kho. Tất cả đều tuỳ chọn — bỏ trống nghĩa là "tất cả".
class InventoryStockFilter {
  const InventoryStockFilter({
    this.warehouseId,
    this.keyword,
    this.lotType,
    this.quarantinedOnly = false,
    this.lowStockOnly = false,
  });

  final int? warehouseId;
  final String? keyword;

  /// PADDY | RICE | BYPRODUCT | PURCHASED_GOOD
  final String? lotType;

  final bool quarantinedOnly;
  final bool lowStockOnly;

  InventoryStockFilter copyWith({
    int? warehouseId,
    bool clearWarehouse = false,
    String? keyword,
    String? lotType,
    bool clearLotType = false,
    bool? quarantinedOnly,
    bool? lowStockOnly,
  }) {
    return InventoryStockFilter(
      warehouseId: clearWarehouse ? null : (warehouseId ?? this.warehouseId),
      keyword: keyword ?? this.keyword,
      lotType: clearLotType ? null : (lotType ?? this.lotType),
      quarantinedOnly: quarantinedOnly ?? this.quarantinedOnly,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
    );
  }

  bool get isEmpty =>
      warehouseId == null &&
      (keyword == null || keyword!.trim().isEmpty) &&
      lotType == null &&
      !quarantinedOnly &&
      !lowStockOnly;
}

abstract class InventoryStockRepository {
  /// Tải tồn kho + KPI + danh sách kho trong một lượt.
  Future<InventoryStockPage> load({
    InventoryStockFilter filter = const InventoryStockFilter(),
    int start = 0,
    int length = 50,
  });
}

/// Đọc tồn kho THẬT từ backend.
///
/// Trước đây màn Kho đọc `getDraftCheck()` — tức phiếu KIỂM KÊ nháp — nên khi
/// tồn tại một phiếu nháp thì màn hình chỉ hiện đúng các dòng trong phiếu đó
/// chứ không phải tồn kho. Repository này gọi đúng hai endpoint tồn kho mà
/// backend đã có sẵn và web đang dùng.
class ApiInventoryStockRepository implements InventoryStockRepository {
  ApiInventoryStockRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Danh sách kho hiếm khi đổi trong một phiên — nạp một lần rồi dùng lại.
  List<WarehouseOption>? _warehouseCache;

  String get _token {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const InventoryStockException(
        'Bạn cần đăng nhập để xem tồn kho.',
      );
    }
    return token;
  }

  @override
  Future<InventoryStockPage> load({
    InventoryStockFilter filter = const InventoryStockFilter(),
    int start = 0,
    int length = 50,
  }) async {
    final token = _token;
    final keyword = filter.keyword?.trim() ?? '';

    final listBody = <String, dynamic>{
      'draw': 1,
      'start': start,
      'length': length,
      'columns': const <dynamic>[],
      'order': const <dynamic>[],
      'search': {'value': keyword, 'regex': false},
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
      if (filter.lotType != null) 'lotType': filter.lotType,
      if (filter.lowStockOnly) 'lowStockOnly': true,
      if (filter.quarantinedOnly) 'isQuarantined': true,
    };

    final summaryBody = <String, dynamic>{
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
      if (filter.lotType != null) 'lotType': filter.lotType,
    };

    try {
      // Ba lượt gọi độc lập → chạy song song cho nhanh.
      final results = await Future.wait([
        _apiClient.post('/api/v1/inventories/advanced',
            token: token, body: listBody),
        _apiClient.post('/api/v1/inventories/summary',
            token: token, body: summaryBody),
        _loadWarehouses(token),
      ]);

      final listJson = results[0] as Map<String, dynamic>;
      final summaryJson = results[1] as Map<String, dynamic>;
      final warehouses = results[2] as List<WarehouseOption>;

      final resources = JsonReader.map(listJson, 'resources');
      final rows = JsonReader.list(resources ?? listJson, 'data') ??
          JsonReader.list(listJson, 'data') ??
          const [];
      final total = JsonReader.integer(resources ?? listJson, 'recordsTotal') ??
          JsonReader.integer(listJson, 'recordsTotal') ??
          rows.length;

      final summaryResources = JsonReader.map(summaryJson, 'resources');

      return InventoryStockPage(
        lines: [
          for (final row in rows.whereType<Map<String, dynamic>>())
            InventoryStockLine.fromJson(row),
        ],
        summary: summaryResources == null
            ? const InventoryStockSummary()
            : InventoryStockSummary.fromJson(summaryResources),
        warehouses: warehouses,
        totalRecords: total,
        loadedAt: DateTime.now(),
      );
    } on ApiException catch (error) {
      throw InventoryStockException(
        error.message,
        isTransient: error.statusCode == null || error.statusCode! >= 500,
      );
    }
  }

  Future<List<WarehouseOption>> _loadWarehouses(String token) async {
    final cached = _warehouseCache;
    if (cached != null) return cached;
    try {
      final json = await _apiClient.get('/api/v1/warehouse', token: token);
      final resources = JsonReader.list(json, 'resources') ?? const [];
      final options = [
        for (final item in resources.whereType<Map<String, dynamic>>())
          WarehouseOption.fromJson(item),
      ]..sort((a, b) => a.name.compareTo(b.name));
      _warehouseCache = options;
      return options;
    } on ApiException {
      // Không có quyền đọc danh mục kho thì vẫn xem được tồn — chỉ mất bộ lọc.
      return const [];
    }
  }
}
