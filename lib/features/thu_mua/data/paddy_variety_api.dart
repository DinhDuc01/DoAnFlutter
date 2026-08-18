import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';

/// Giống lúa (rice variety) để chọn trên phiếu thu mua.
class RiceVarietyOption {
  const RiceVarietyOption({required this.id, required this.name});

  final int id;
  final String name;
}

/// Biến thể sản phẩm lúa kèm giống — để lọc sản phẩm theo giống đã chọn,
/// đồng bộ với web (`/paddy-purchase-receipts/product-variants`).
class PaddyVariantOption {
  const PaddyVariantOption({
    required this.id,
    required this.name,
    this.sku,
    this.riceVarietyId,
    this.riceVarietyName,
  });

  final int id;
  final String name;
  final String? sku;
  final int? riceVarietyId;
  final String? riceVarietyName;
}

/// Gọi API giống lúa + biến thể sản phẩm lúa (nguồn để lọc sản phẩm theo giống).
class PaddyVarietyApi {
  PaddyVarietyApi({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<RiceVarietyOption>> getRiceVarieties() async {
    final json = await _apiClient.get(
      '/api/v1/rice-varieties',
      token: _token(),
    );
    return _rows(json)
        .map((item) => RiceVarietyOption(
              id: JsonReader.integer(item, 'id') ?? 0,
              name: JsonReader.string(item, 'name') ??
                  JsonReader.string(item, 'riceVarietyName') ??
                  'Giống lúa',
            ))
        .where((item) => item.id > 0)
        .toList();
  }

  Future<List<PaddyVariantOption>> getProductVariants() async {
    final json = await _apiClient.get(
      '/api/v1/paddy-purchase-receipts/product-variants',
      token: _token(),
    );
    return _rows(json)
        .map((item) => PaddyVariantOption(
              id: JsonReader.integer(item, 'id') ?? 0,
              name: JsonReader.string(item, 'name') ??
                  JsonReader.string(item, 'productName') ??
                  'Sản phẩm',
              sku: JsonReader.string(item, 'sku'),
              riceVarietyId: JsonReader.integer(item, 'riceVarietyId'),
              riceVarietyName: JsonReader.string(item, 'riceVarietyName'),
            ))
        .where((item) => item.id > 0)
        .toList();
  }

  /// Đọc danh sách từ nhiều dạng bao ngoài (resources là List hoặc DataTables).
  List<Map<String, dynamic>> _rows(Map<String, dynamic> json) {
    final value = JsonReader.value(json, 'resources');
    List<dynamic> list;
    if (value is List) {
      list = value;
    } else if (value is Map<String, dynamic>) {
      list = JsonReader.list(value, 'dataSource') ??
          JsonReader.list(value, 'items') ??
          JsonReader.list(value, 'data') ??
          const [];
    } else {
      list = const [];
    }
    return [
      for (final item in list)
        if (item is Map<String, dynamic> &&
            (JsonReader.boolean(item, 'isActive') ?? true))
          item,
    ];
  }

  String _token() {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiException(
        message: 'Bạn cần đăng nhập để tải giống lúa/sản phẩm.',
      );
    }
    return token;
  }
}
