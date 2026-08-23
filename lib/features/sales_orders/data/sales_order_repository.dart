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

  /// Tạo đơn bán mới (trạng thái NEW). Trả về id + mã đơn vừa tạo.
  ///
  /// Việc XÁC NHẬN đơn (NEW → Chờ xác nhận) chỉ làm trên web; mobile không gọi
  /// `/confirm`. Mobile chỉ tạo đơn và kiểm tra & giữ hàng ([reserve]).
  Future<CreatedSalesOrder> create(CreateSalesOrderInput input);

  /// Duyệt/xác nhận đơn bán mới: NEW -> PENDING_CONFIRM.
  Future<void> confirm(int id);

  /// Kiểm tra & giữ hàng: Chờ xác nhận → Đã giữ hàng.
  /// Backend kiểm tra khách hàng, hạn mức công nợ và tồn khả dụng.
  Future<void> reserve(int id);

  /// Hủy đơn bán kèm lý do (backend lưu vào cột `CancelReason`).
  Future<void> cancel(int id, {required String reason});

  /// Tạo phiếu xuất (OutboundOrder DRAFT) từ đơn bán. Trả về id phiếu xuất.
  Future<int> createOutbound(int id, List<CreateOutboundLine> items);

  /// Khách hàng đang hoạt động để chọn khi tạo đơn.
  Future<List<SalesCustomerOption>> getCustomers();

  /// Kho xuất hàng để chọn khi tạo đơn.
  Future<List<SalesWarehouseOption>> getWarehouses();

  /// Biến thể sản phẩm đang hoạt động (kèm giá bán gợi ý) để chọn dòng hàng.
  Future<List<SalesProductOption>> getProductVariants({String keyword = ''});
}

/// Kết quả trả về sau khi tạo đơn bán.
class CreatedSalesOrder {
  const CreatedSalesOrder({
    required this.id,
    required this.soCode,
    required this.totalAmount,
  });

  final int id;
  final String soCode;
  final double totalAmount;
}

/// Dữ liệu tạo đơn bán — khớp `CreateSalesOrderDto` của backend.
/// BE tự tính LineAmount/TotalAmount nên mobile không gửi thành tiền.
class CreateSalesOrderInput {
  const CreateSalesOrderInput({
    required this.customerId,
    required this.warehouseId,
    required this.channel,
    required this.items,
    this.expectedDeliveryDate,
    this.requiresMilling = false,
    this.depositAmount,
    this.shippingAddress,
    this.note,
  });

  final int customerId;
  final int warehouseId;

  /// DIRECT | WHOLESALE
  final String channel;
  final DateTime? expectedDeliveryDate;
  final bool requiresMilling;
  final double? depositAmount;
  final String? shippingAddress;
  final String? note;
  final List<CreateSalesOrderLine> items;

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'warehouseId': warehouseId,
        'channel': channel.toUpperCase(),
        'expectedDeliveryDate': expectedDeliveryDate?.toIso8601String(),
        'requiresMilling': requiresMilling,
        'depositAmount': depositAmount,
        'shippingAddress': _blankToNull(shippingAddress),
        'note': _blankToNull(note),
        'items': [for (final item in items) item.toJson()],
      };
}

/// Một dòng hàng khi tạo đơn bán.
class CreateSalesOrderLine {
  const CreateSalesOrderLine({
    required this.productVariantId,
    required this.quantityOrdered,
    required this.unitSalePrice,
    this.discountAmount = 0,
    this.note,
  });

  final int productVariantId;
  final double quantityOrdered;
  final double unitSalePrice;
  final double discountAmount;
  final String? note;

  /// Thành tiền hiển thị trên mobile (BE tính lại khi lưu).
  double get lineAmount {
    final amount = quantityOrdered * unitSalePrice - discountAmount;
    return amount < 0 ? 0 : amount;
  }

  Map<String, dynamic> toJson() => {
        'productVariantId': productVariantId,
        'quantityOrdered': quantityOrdered,
        'unitSalePrice': unitSalePrice,
        'discountAmount': discountAmount,
        'note': _blankToNull(note),
      };

  CreateSalesOrderLine copyWith({
    double? quantityOrdered,
    double? unitSalePrice,
    double? discountAmount,
    String? note,
  }) =>
      CreateSalesOrderLine(
        productVariantId: productVariantId,
        quantityOrdered: quantityOrdered ?? this.quantityOrdered,
        unitSalePrice: unitSalePrice ?? this.unitSalePrice,
        discountAmount: discountAmount ?? this.discountAmount,
        note: note ?? this.note,
      );
}

/// Khách hàng để chọn trên form tạo đơn.
class SalesCustomerOption {
  const SalesCustomerOption({
    required this.id,
    required this.name,
    this.code,
    this.phone,
    this.address,
  });

  final int id;
  final String name;
  final String? code;
  final String? phone;
  final String? address;

  String get label =>
      (code ?? '').trim().isEmpty ? name : '${code!.trim()} - $name';
}

/// Kho xuất hàng để chọn trên form tạo đơn.
class SalesWarehouseOption {
  const SalesWarehouseOption({
    required this.id,
    required this.name,
    this.code,
  });

  final int id;
  final String name;
  final String? code;

  String get label =>
      (code ?? '').trim().isEmpty ? name : '${code!.trim()} - $name';
}

/// Biến thể sản phẩm để chọn dòng hàng.
class SalesProductOption {
  const SalesProductOption({
    required this.id,
    required this.name,
    this.sku,
    this.salePrice = 0,
    this.unitName,
    this.productCategoryId,
    this.productCategoryName,
  });

  /// Các ID danh mục được Backend seed và Web dùng cho hàng được phép bán.
  /// Đơn bán Mobile chỉ nhận Gạo thành phẩm và Phụ phẩm, không nhận Lúa thô
  /// hoặc danh mục không xác định.
  static const int rawPaddyCategoryId = 101;
  static const int finishedRiceCategoryId = 102;
  static const int byproductCategoryId = 103;

  final int id;
  final String name;
  final String? sku;
  final double salePrice;
  final String? unitName;
  final int? productCategoryId;
  final String? productCategoryName;

  bool get isRawPaddy => productCategoryId == rawPaddyCategoryId;

  bool get isAllowedSalesProduct =>
      productCategoryId == finishedRiceCategoryId ||
      productCategoryId == byproductCategoryId;

  String get label =>
      (sku ?? '').trim().isEmpty ? name : '$name · ${sku!.trim()}';
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
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
            'channel': (channel ?? '').trim().isEmpty
                ? null
                : channel!.trim().toUpperCase(),
            'page': page < 1 ? 1 : page,
            'pageSize': pageSize,
          },
        ));

    final resources = JsonReader.map(json, 'resources');
    if (resources == null) {
      throw const SalesOrderException(
          'Backend không trả về danh sách đơn bán.');
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
  Future<void> confirm(int id) async {
    if (id <= 0) {
      throw const SalesOrderException('Mã đơn bán không hợp lệ.');
    }
    await _guard(() => _api.post(
          '/api/v1/sales-orders/$id/confirm',
          token: _token,
          body: const {},
        ));
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
  Future<CreatedSalesOrder> create(CreateSalesOrderInput input) async {
    if (input.customerId <= 0) {
      throw const SalesOrderException('Vui lòng chọn khách hàng.');
    }
    if (input.warehouseId <= 0) {
      throw const SalesOrderException('Vui lòng chọn kho xuất hàng.');
    }
    if (input.items.isEmpty) {
      throw const SalesOrderException(
          'Đơn bán phải có ít nhất 1 dòng sản phẩm.');
    }
    // Backend từ chối trùng biến thể trên cùng đơn — chặn sớm để báo lỗi rõ hơn.
    final variantIds = input.items.map((x) => x.productVariantId).toList();
    if (variantIds.toSet().length != variantIds.length) {
      throw const SalesOrderException(
        'Không được thêm trùng cùng một sản phẩm (SKU) trên đơn bán.',
      );
    }
    if (input.items.any((x) => x.quantityOrdered <= 0)) {
      throw const SalesOrderException(
          'Số lượng của mỗi dòng hàng phải lớn hơn 0.');
    }
    if (input.items.any((x) => x.unitSalePrice < 0 || x.discountAmount < 0)) {
      throw const SalesOrderException('Đơn giá và giảm giá không được âm.');
    }

    final json = await _guard(() => _api.post(
          '/api/v1/sales-orders',
          token: _token,
          body: input.toJson(),
        ));

    final resources = JsonReader.map(json, 'resources');
    return CreatedSalesOrder(
      id: resources == null ? 0 : JsonReader.integer(resources, 'id') ?? 0,
      soCode:
          resources == null ? '' : JsonReader.string(resources, 'soCode') ?? '',
      totalAmount: resources == null
          ? 0
          : JsonReader.decimal(resources, 'totalAmount') ?? 0,
    );
  }

  @override
  Future<void> reserve(int id) async {
    if (id <= 0) throw const SalesOrderException('Mã đơn bán không hợp lệ.');
    await _guard(() => _api.post(
          '/api/v1/sales-orders/$id/reserve',
          token: _token,
          body: const {},
        ));
  }

  @override
  Future<List<SalesCustomerOption>> getCustomers() async {
    final json =
        await _guard(() => _api.get('/api/v1/customers', token: _token));
    return [
      for (final row in _rows(json))
        if ((JsonReader.boolean(row, 'isActive') ?? true) &&
            (JsonReader.integer(row, 'id') ?? 0) > 0)
          SalesCustomerOption(
            id: JsonReader.integer(row, 'id')!,
            name: JsonReader.string(row, 'name') ?? 'Khách hàng',
            code: JsonReader.string(row, 'code'),
            phone: JsonReader.string(row, 'phone'),
            address: JsonReader.string(row, 'address'),
          ),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<List<SalesWarehouseOption>> getWarehouses() async {
    final json =
        await _guard(() => _api.get('/api/v1/warehouse', token: _token));
    return [
      for (final row in _rows(json))
        if ((JsonReader.boolean(row, 'isActive') ?? true) &&
            (JsonReader.integer(row, 'id') ?? 0) > 0)
          SalesWarehouseOption(
            id: JsonReader.integer(row, 'id')!,
            name: JsonReader.string(row, 'name') ??
                JsonReader.string(row, 'warehouseName') ??
                'Kho',
            code: JsonReader.string(row, 'code'),
          ),
    ];
  }

  @override
  Future<List<SalesProductOption>> getProductVariants(
      {String keyword = ''}) async {
    // Dùng đúng endpoint web đang dùng để danh sách sản phẩm khớp nhau.
    final query = {
      'pageIndex': '1',
      'pageSize': '1000',
      'isActive': 'true',
      if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
    };
    final json = await _guard(
      () => _api.get('/api/v1/product-variant/search',
          query: query, token: _token),
    );
    final products = [
      for (final row in _rows(json))
        if ((JsonReader.integer(row, 'id') ?? 0) > 0)
          SalesProductOption(
            id: JsonReader.integer(row, 'id')!,
            name: JsonReader.string(row, 'name') ??
                JsonReader.string(row, 'productName') ??
                'Sản phẩm',
            sku: JsonReader.string(row, 'sku'),
            salePrice: JsonReader.decimal(row, 'salePrice') ?? 0,
            unitName: JsonReader.string(row, 'unitOfMeasureName') ??
                JsonReader.string(row, 'unitName'),
            productCategoryId: JsonReader.integer(row, 'productCategoryId') ??
                JsonReader.integer(row, 'ProductCategoryId'),
            productCategoryName:
                JsonReader.string(row, 'productCategoryName') ??
                    JsonReader.string(row, 'ProductCategoryName'),
          ),
    ];

    // Đồng bộ Web: chỉ cho bán Gạo thành phẩm (102) và Phụ phẩm (103).
    // Dùng allow-list category từ Backend thay vì đoán bằng tên/SKU; record thiếu
    // category cũng bị loại để không vô tình đưa nguyên liệu vào đơn bán.
    return products.where((product) => product.isAllowedSalesProduct).toList();
  }

  /// Đọc danh sách từ nhiều dạng bao ngoài: `resources` là List, hoặc là Map
  /// chứa `dataSource`/`items` (endpoint search phân trang).
  List<Map<String, dynamic>> _rows(Map<String, dynamic> json) {
    final value = JsonReader.value(json, 'resources');
    final list = switch (value) {
      List<dynamic> items => items,
      Map<String, dynamic> page => JsonReader.list(page, 'dataSource') ??
          JsonReader.list(page, 'items') ??
          JsonReader.list(page, 'data') ??
          JsonReader.list(page, 'results') ??
          const <dynamic>[],
      _ => const <dynamic>[],
    };
    return [
      for (final row in list)
        if (row is Map<String, dynamic>) row,
    ];
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
          body: {
            'items': [for (final item in items) item.toJson()]
          },
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
