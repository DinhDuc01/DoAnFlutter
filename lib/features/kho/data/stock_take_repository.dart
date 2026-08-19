import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/inventory_stock.dart' show WarehouseOption;
import '../models/stock_take.dart';

class StockTakeException implements Exception {
  const StockTakeException(this.message, {this.isTransient = false});

  final String message;
  final bool isTransient;

  @override
  String toString() => message;
}

/// Phạm vi chụp phiếu kiểm kê.
enum StockTakeScope { warehouse, zone, column, lot }

extension StockTakeScopeX on StockTakeScope {
  String get code => switch (this) {
        StockTakeScope.warehouse => 'WAREHOUSE',
        StockTakeScope.zone => 'ZONE',
        StockTakeScope.column => 'COLUMN',
        StockTakeScope.lot => 'LOT',
      };

  String get label => switch (this) {
        StockTakeScope.warehouse => 'Toàn kho',
        StockTakeScope.zone => 'Theo khu',
        StockTakeScope.column => 'Theo cột/vị trí',
        StockTakeScope.lot => 'Theo lô',
      };

  static StockTakeScope fromCode(String? code) =>
      switch ((code ?? '').toUpperCase()) {
        'ZONE' => StockTakeScope.zone,
        'LOT' => StockTakeScope.lot,
        'WAREHOUSE' => StockTakeScope.warehouse,
        _ => StockTakeScope.column,
      };
}

/// Một cột/vị trí để chọn phạm vi kiểm kê.
class StockTakeLocationOption {
  const StockTakeLocationOption({
    required this.id,
    required this.warehouseId,
    required this.zoneName,
    required this.label,
  });

  final int id;
  final int warehouseId;
  final String zoneName;
  final String label;
}

abstract class StockTakeRepository {
  Future<List<StockTakeSummaryRow>> getStockTakes();
  Future<StockTakeDetail> getDetail(int id);
  Future<int> create({
    required int warehouseId,
    required StockTakeScope scope,
    String? zoneName,
    int? locationId,
    int? paddyLotId,
    String? note,
  });
  Future<void> saveCounts(int id, List<StockTakeLine> lines, {String? note});
  Future<void> submit(int id, {String? note});
  Future<void> approve(int id, {String? approveNote});
  Future<void> reject(int id, {required String reason});
  Future<void> delete(int id);
  Future<ScanBagResult> scanBag(int id, String qrCode, {double? countedWeightKg});
  Future<List<StockTakeLocationOption>> getLocations(int warehouseId);
  Future<List<WarehouseOption>> getWarehouses();

  /// Khu / cột / lô ĐANG CÓ BAO để chọn phạm vi kiểm kê.
  Future<StockTakeScopeOptions> getScopeOptions(int warehouseId, {bool? quarantineOnly});

  /// Quét QR dán trên khu/cột hoặc lô để chọn nhanh phạm vi.
  Future<StockTakeScopeResolve> resolveScopeQr(String qrCode, {int? warehouseId});

  /// Gợi ý ô cách ly / cột thường cho một bao (vẫn chọn lại được).
  Future<List<BagTargetSuggestion>> getBagTargets(int stockTakeId, int bagId);
}

/// Kiểm kê theo BAO — đọc/ghi thẳng API `/stocktakes`.
///
/// Backend là nơi chụp snapshot phiếu (gồm cả danh sách bao) và tính toán
/// chênh lệch; app chỉ chọn phạm vi rồi ghi lại kết quả kiểm đếm từng bao.
/// Client KHÔNG tự dựng dòng phiếu từ danh mục sản phẩm — làm vậy thì số liệu
/// gửi lên chỉ là phỏng đoán của app, không phải tồn kho thật.
class ApiStockTakeRepository implements StockTakeRepository {
  ApiStockTakeRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  String get _token {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const StockTakeException('Bạn cần đăng nhập để kiểm kê kho.');
    }
    return token;
  }

  Never _rethrow(ApiException error) => throw StockTakeException(
        error.message,
        isTransient: error.statusCode == null || error.statusCode! >= 500,
      );

  void _requireSuccess(Map<String, dynamic> response) {
    if (response['isSucceeded'] == false) {
      throw StockTakeException(JsonReader.string(response, 'message') ?? 'Thao tác thất bại.');
    }
  }

  @override
  Future<List<StockTakeSummaryRow>> getStockTakes() async {
    try {
      final json = await _apiClient.get('/api/v1/stocktakes', token: _token);
      final resources = JsonReader.value(json, 'resources');
      final rows = switch (resources) {
        List<dynamic> items => items,
        Map<String, dynamic> page => JsonReader.list(page, 'data') ?? const [],
        _ => const <dynamic>[],
      };
      return [
        for (final row in rows.whereType<Map<String, dynamic>>())
          StockTakeSummaryRow.fromJson(row),
      ]..sort((a, b) => b.id.compareTo(a.id));
    } on ApiException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Future<StockTakeDetail> getDetail(int id) async {
    try {
      final json = await _apiClient.get('/api/v1/stocktakes/$id', token: _token);
      final resources = JsonReader.map(json, 'resources');
      if (resources == null) {
        throw const StockTakeException('Không đọc được chi tiết phiếu kiểm kê.');
      }
      return StockTakeDetail.fromJson(resources);
    } on ApiException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Future<int> create({
    required int warehouseId,
    required StockTakeScope scope,
    String? zoneName,
    int? locationId,
    int? paddyLotId,
    String? note,
  }) async {
    try {
      final json = await _apiClient.post(
        '/api/v1/stocktakes',
        token: _token,
        body: {
          'warehouseId': warehouseId,
          // 0 = để backend tự gán trạng thái Nháp theo Code (không hard-code Id).
          'stockTakeStatusId': 0,
          'scopeType': scope.code,
          if (zoneName != null) 'zoneName': zoneName,
          if (locationId != null) 'locationId': locationId,
          if (paddyLotId != null) 'paddyLotId': paddyLotId,
          'note': note?.trim(),
          // Danh sách dòng do BACKEND chụp: client không được tự bịa tồn kho.
          'stockTakeItems': const <dynamic>[],
        },
      );
      final resources = JsonReader.value(json, 'resources');
      if (resources is num) return resources.toInt();
      if (resources is Map<String, dynamic>) {
        return JsonReader.integer(resources, 'id') ?? 0;
      }
      return 0;
    } on ApiException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Future<void> saveCounts(int id, List<StockTakeLine> lines, {String? note}) async {
    try {
      await _apiClient.put(
        '/api/v1/stocktakes/$id/counts',
        token: _token,
        body: {
          'note': note?.trim(),
          'items': [for (final line in lines) line.toSaveJson()],
        },
      );
    } on ApiException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Future<void> submit(int id, {String? note}) async {
    try {
      await _apiClient.put(
        '/api/v1/stocktakes/$id/submit',
        token: _token,
        body: {'note': note?.trim()},
      );
    } on ApiException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Future<void> approve(int id, {String? approveNote}) async {
    try {
      final response = await _apiClient.put(
        '/api/v1/stocktakes/$id/approve',
        token: _token,
        body: {'approveNote': approveNote?.trim()},
      );
      _requireSuccess(response);
    } on ApiException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Future<void> reject(int id, {required String reason}) async {
    try {
      final response = await _apiClient.put(
        '/api/v1/stocktakes/$id/reject',
        token: _token,
        body: {'reason': reason.trim()},
      );
      _requireSuccess(response);
    } on ApiException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      final response = await _apiClient.delete('/api/v1/stocktakes/$id', token: _token);
      _requireSuccess(response);
    } on ApiException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Future<ScanBagResult> scanBag(int id, String qrCode, {double? countedWeightKg}) async {
    try {
      final json = await _apiClient.post(
        '/api/v1/stocktakes/$id/scan-bag',
        token: _token,
        body: {
          'qrCode': qrCode.trim(),
          if (countedWeightKg != null) 'countedWeightKg': countedWeightKg,
        },
      );
      final resources = JsonReader.map(json, 'resources');
      if (resources == null) {
        return const ScanBagResult(
          matched: false,
          message: 'Không đọc được kết quả tra mã.',
        );
      }
      return ScanBagResult.fromJson(resources);
    } on ApiException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Future<StockTakeScopeOptions> getScopeOptions(int warehouseId, {bool? quarantineOnly}) async {
    try {
      final query = quarantineOnly == null ? '' : '&quarantineOnly=$quarantineOnly';
      final json = await _apiClient.get(
        '/api/v1/stocktakes/scope-options?warehouseId=$warehouseId$query',
        token: _token,
      );
      final resources = JsonReader.map(json, 'resources');
      if (resources == null) return const StockTakeScopeOptions();
      return StockTakeScopeOptions.fromJson(resources);
    } on ApiException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Future<StockTakeScopeResolve> resolveScopeQr(String qrCode, {int? warehouseId}) async {
    try {
      final query = warehouseId == null ? '' : '&warehouseId=$warehouseId';
      final json = await _apiClient.get(
        '/api/v1/stocktakes/scope-resolve?qrCode=${Uri.encodeQueryComponent(qrCode.trim())}$query',
        token: _token,
      );
      final resources = JsonReader.map(json, 'resources');
      if (resources == null) {
        return const StockTakeScopeResolve(
          matched: false,
          message: 'Không đọc được kết quả tra mã.',
        );
      }
      return StockTakeScopeResolve.fromJson(resources);
    } on ApiException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Future<List<BagTargetSuggestion>> getBagTargets(int stockTakeId, int bagId) async {
    try {
      final json = await _apiClient.get(
        '/api/v1/stocktakes/$stockTakeId/bags/$bagId/target-suggestions',
        token: _token,
      );
      final resources = JsonReader.list(json, 'resources') ?? const [];
      return [
        for (final row in resources.whereType<Map<String, dynamic>>())
          BagTargetSuggestion.fromJson(row),
      ];
    } on ApiException {
      // Không lấy được gợi ý thì vẫn cho chọn tay ở màn hình.
      return const [];
    }
  }

  @override
  Future<List<WarehouseOption>> getWarehouses() async {
    try {
      final json = await _apiClient.get('/api/v1/warehouse', token: _token);
      final resources = JsonReader.list(json, 'resources') ?? const [];
      return [
        for (final row in resources.whereType<Map<String, dynamic>>())
          WarehouseOption.fromJson(row),
      ]..sort((a, b) => a.name.compareTo(b.name));
    } on ApiException catch (error) {
      _rethrow(error);
    }
  }

  @override
  Future<List<StockTakeLocationOption>> getLocations(int warehouseId) async {
    try {
      final json = await _apiClient.get('/api/v1/location', token: _token);
      final resources = JsonReader.value(json, 'resources');
      final rows = switch (resources) {
        List<dynamic> items => items,
        Map<String, dynamic> page => JsonReader.list(page, 'data') ?? const [],
        _ => const <dynamic>[],
      };
      final options = <StockTakeLocationOption>[];
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final id = JsonReader.integer(row, 'id') ?? 0;
        final wh = JsonReader.integer(row, 'warehouseId') ?? 0;
        if (id <= 0 || wh != warehouseId) continue;
        final zone = JsonReader.string(row, 'zoneName') ?? '';
        final slot = JsonReader.string(row, 'slotCode') ??
            [
              JsonReader.string(row, 'shelfRow'),
              JsonReader.string(row, 'shelfLevel'),
            ].where((x) => (x ?? '').isNotEmpty).join('-');
        options.add(StockTakeLocationOption(
          id: id,
          warehouseId: wh,
          zoneName: zone,
          label: [zone, slot].where((x) => x.isNotEmpty).join(' / '),
        ));
      }
      options.sort((a, b) => a.label.compareTo(b.label));
      return options;
    } on ApiException {
      // Thiếu quyền đọc danh mục vị trí thì vẫn kiểm kê toàn kho được.
      return const [];
    }
  }
}
