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
    this.lotStatusId,
    this.quarantinedOnly = false,
    this.lowStockOnly = false,
  });

  final int? warehouseId;
  final String? keyword;

  /// PADDY | RICE | BYPRODUCT | PURCHASED_GOOD
  final String? lotType;

  /// Trạng thái lô (LotStatus.Id) — ví dụ chỉ xem lô "Đang cách ly".
  final int? lotStatusId;

  final bool quarantinedOnly;
  final bool lowStockOnly;

  InventoryStockFilter copyWith({
    int? warehouseId,
    bool clearWarehouse = false,
    String? keyword,
    String? lotType,
    bool clearLotType = false,
    int? lotStatusId,
    bool clearLotStatus = false,
    bool? quarantinedOnly,
    bool? lowStockOnly,
  }) {
    return InventoryStockFilter(
      warehouseId: clearWarehouse ? null : (warehouseId ?? this.warehouseId),
      keyword: keyword ?? this.keyword,
      lotType: clearLotType ? null : (lotType ?? this.lotType),
      lotStatusId: clearLotStatus ? null : (lotStatusId ?? this.lotStatusId),
      quarantinedOnly: quarantinedOnly ?? this.quarantinedOnly,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
    );
  }

  bool get isEmpty =>
      warehouseId == null &&
      (keyword == null || keyword!.trim().isEmpty) &&
      lotType == null &&
      lotStatusId == null &&
      !quarantinedOnly &&
      !lowStockOnly;
}

abstract class InventoryStockRepository {
  /// Tải một trang tồn kho + KPI + danh mục cho bộ lọc.
  ///
  /// [start]/[length] là cửa sổ phân trang kiểu DataTables; màn hình gọi lại
  /// với [start] tăng dần để cuộn tới đâu tải tới đó.
  Future<InventoryStockPage> load({
    InventoryStockFilter filter = const InventoryStockFilter(),
    int start = 0,
    int length = 30,
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

  /// Danh mục hiếm khi đổi trong một phiên — nạp một lần rồi dùng lại.
  List<WarehouseOption>? _warehouseCache;
  List<LotStatusOption>? _lotStatusCache;

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
    int length = 30,
  }) async {
    final token = _token;
    final keyword = filter.keyword?.trim() ?? '';

    // Bộ lọc dùng chung cho BẢNG và 5 THẺ. Trước đây thẻ chỉ nhận kho + loại
    // hàng nên bật "Cách ly" thì danh sách đổi mà thẻ đứng yên — nhìn như số
    // liệu sai. Backend nay nhận cùng bộ trường (xem InventorySummaryParameters).
    final commonFilters = <String, dynamic>{
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
      if (filter.lotType != null) 'lotType': filter.lotType,
      if (filter.lotStatusId != null) 'lotStatusId': filter.lotStatusId,
      if (filter.lowStockOnly) 'lowStockOnly': true,
      if (filter.quarantinedOnly) 'isQuarantined': true,
    };

    final listBody = <String, dynamic>{
      'draw': 1,
      'start': start,
      'length': length,
      'columns': const <dynamic>[],
      'order': const <dynamic>[],
      'search': {'value': keyword, 'regex': false},
      ...commonFilters,
    };

    final summaryBody = <String, dynamic>{
      if (keyword.isNotEmpty) 'search': keyword,
      ...commonFilters,
    };

    try {
      // Bốn lượt gọi độc lập → chạy song song cho nhanh.
      final results = await Future.wait([
        _apiClient.post('/api/v1/inventories/advanced',
            token: token, body: listBody),
        _apiClient.post('/api/v1/inventories/summary',
            token: token, body: summaryBody),
        _loadWarehouses(token),
        _loadLotStatuses(token),
      ]);

      final listJson = results[0] as Map<String, dynamic>;
      final summaryJson = results[1] as Map<String, dynamic>;
      final warehouses = results[2] as List<WarehouseOption>;
      final lotStatuses = results[3] as List<LotStatusOption>;

      final resources = JsonReader.map(listJson, 'resources');
      final rows = JsonReader.list(resources ?? listJson, 'data') ??
          JsonReader.list(listJson, 'data') ??
          const [];
      // recordsFiltered = số dòng khớp BỘ LỌC; recordsTotal là tổng chưa lọc.
      // Phân trang và dòng đếm "đang hiện x/y" phải bám số ĐÃ lọc, nếu không
      // vừa lọc xong màn hình vẫn khoe tổng toàn kho và đòi tải thêm mãi.
      final scope = resources ?? listJson;
      final total = JsonReader.integer(scope, 'recordsFiltered') ??
          JsonReader.integer(scope, 'recordsTotal') ??
          JsonReader.integer(listJson, 'recordsFiltered') ??
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
        lotStatuses: lotStatuses,
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

  /// Danh mục trạng thái lô — để lọc "chỉ lô đang cách ly", "chờ xử lý"…
  Future<List<LotStatusOption>> _loadLotStatuses(String token) async {
    final cached = _lotStatusCache;
    if (cached != null) return cached;
    try {
      final json = await _apiClient.get('/api/v1/lot-status', token: token);
      // Endpoint danh mục có nơi trả mảng thẳng, có nơi bọc trong trang
      // DataTables — nhận cả hai để không phụ thuộc cấu hình từng môi trường.
      final resources = JsonReader.value(json, 'resources');
      final rows = switch (resources) {
        List<dynamic> items => items,
        Map<String, dynamic> page => JsonReader.list(page, 'data') ??
            JsonReader.list(page, 'dataSource') ??
            const <dynamic>[],
        _ => const <dynamic>[],
      };
      final options = [
        for (final item in rows.whereType<Map<String, dynamic>>())
          LotStatusOption.fromJson(item),
      ].where((option) => option.id > 0).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _lotStatusCache = options;
      return options;
    } on ApiException {
      return const [];
    }
  }
}
