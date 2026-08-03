/// Đại diện cho một phiếu kiểm kê kho hàng (Inventory Check).
class KhoCheck {
  /// Khởi tạo [KhoCheck] với các thông số bắt buộc.
  const KhoCheck({
    required this.warehouseId,
    required this.checkCode,
    required this.warehouseName,
    required this.noteHint,
    required this.items,
    required this.checkedAt,
  });

  final int warehouseId;

  /// Mã phiếu kiểm kê.
  final String checkCode;

  /// Tên của kho hàng đang tiến hành kiểm kê.
  final String warehouseName;

  /// Gợi ý ghi chú mặc định của phiếu kiểm kê.
  final String noteHint;

  /// Danh sách các sản phẩm cần kiểm kê trong phiếu này.
  final List<KhoCheckItem> items;

  /// Time at which this inventory snapshot was loaded.
  final DateTime checkedAt;

  /// Tổng số lượng loại sản phẩm trong phiếu.
  int get totalProducts => items.length;

  /// Tổng số lượng sản phẩm dự tính trên hệ thống.
  int get totalSystemQuantity {
    return items.fold(0, (sum, item) => sum + item.systemQuantity);
  }
}

/// Một dòng sản phẩm trong phiếu kiểm kê tồn kho.
class KhoCheckItem {
  /// Khởi tạo một dòng kiểm kê sản phẩm [KhoCheckItem].
  const KhoCheckItem({
    required this.productVariantId,
    required this.productName,
    required this.sku,
    required this.systemQuantity,
    this.locationId,
    this.lastStockTakeDate,
    this.actualQuantity,
  });

  final int productVariantId;

  /// Tên sản phẩm.
  final String productName;

  /// Mã định danh sản phẩm (SKU).
  final String sku;

  /// Số lượng sản phẩm ghi nhận trên hệ thống.
  final int systemQuantity;
  final int? locationId;

  final DateTime? lastStockTakeDate;

  /// Số lượng sản phẩm đếm được thực tế (có thể null nếu chưa nhập).
  final int? actualQuantity;

  /// Số lượng chênh lệch giữa thực tế và hệ thống. Trả về null nếu chưa kiểm đếm thực tế.
  int? get difference {
    if (actualQuantity == null) return null;
    return actualQuantity! - systemQuantity;
  }

  /// Tạo một bản sao mới với số lượng thực tế được cập nhật hoặc xóa đi.
  KhoCheckItem copyWith({
    int? actualQuantity,
    bool clearActualQuantity = false,
  }) {
    return KhoCheckItem(
      productVariantId: productVariantId,
      productName: productName,
      sku: sku,
      systemQuantity: systemQuantity,
      locationId: locationId,
      lastStockTakeDate: lastStockTakeDate,
      actualQuantity:
          clearActualQuantity ? null : actualQuantity ?? this.actualQuantity,
    );
  }
}
