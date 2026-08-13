import '../../../core/api/json_reader.dart';

/// Một dòng tồn kho thật: một lô nằm ở một vị trí trong một kho.
///
/// Khác với [KhoCheckItem] (dòng của phiếu kiểm kê), đây là dữ liệu tồn kho
/// hiện hành do `/api/v1/inventories/advanced` trả về. Toàn bộ khối lượng giữ
/// nguyên kiểu `double` — lúa gạo luôn có phần lẻ kg, làm tròn về `int` là mất
/// dữ liệu.
class InventoryStockLine {
  const InventoryStockLine({
    required this.id,
    required this.warehouseId,
    required this.productVariantId,
    required this.quantityOnHand,
    required this.quantityReserved,
    required this.quantityAvailable,
    this.warehouseName,
    this.locationId,
    this.locationCode,
    this.sku,
    this.productVariantName,
    this.productName,
    this.categoryName,
    this.unitName,
    this.unitWeightKg = 0,
    this.totalWeightKg = 0,
    this.quantityQuarantine = 0,
    this.quantityProcessing = 0,
    this.sellableOnHandKg = 0,
    this.otherBlockedKg = 0,
    this.bags = 0,
    this.openBags = 0,
    this.hasPhysicalBagData = false,
    this.minStockLevel,
    this.isLowStock = false,
    this.paddyLotId,
    this.lotCode,
    this.lotType,
    this.lotStatusName,
    this.lotStatusColor,
    this.lotQualityStatus,
    this.lotIsSellable,
    this.lotInboundDate,
    this.lastStockTakeDate,
    this.isByproduct = false,
  });

  final int id;
  final int warehouseId;
  final String? warehouseName;
  final int? locationId;
  final String? locationCode;

  final int productVariantId;
  final String? sku;
  final String? productVariantName;
  final String? productName;
  final String? categoryName;
  final String? unitName;
  final double unitWeightKg;
  final bool isByproduct;

  final double quantityOnHand;
  final double quantityReserved;
  final double quantityAvailable;
  final double quantityQuarantine;
  final double quantityProcessing;
  final double sellableOnHandKg;
  final double otherBlockedKg;
  final double totalWeightKg;

  final int bags;
  final int openBags;
  final bool hasPhysicalBagData;

  final double? minStockLevel;
  final bool isLowStock;

  final int? paddyLotId;
  final String? lotCode;
  final String? lotType;
  final String? lotStatusName;
  final String? lotStatusColor;
  final String? lotQualityStatus;
  final bool? lotIsSellable;
  final DateTime? lotInboundDate;
  final DateTime? lastStockTakeDate;

  /// Nhãn hiển thị cho dòng: ưu tiên mã lô, không có lô thì dùng SKU.
  String get title => lotCode?.trim().isNotEmpty == true
      ? lotCode!.trim()
      : (sku?.trim().isNotEmpty == true ? sku!.trim() : 'INV-$id');

  String get productLabel =>
      productVariantName?.trim().isNotEmpty == true
          ? productVariantName!.trim()
          : (productName ?? 'Sản phẩm $productVariantId');

  String get locationLabel =>
      locationCode?.trim().isNotEmpty == true ? locationCode!.trim() : '—';

  String get unitLabel =>
      unitName?.trim().isNotEmpty == true ? unitName!.trim() : 'kg';

  bool get isQuarantined => quantityQuarantine > 0;
  bool get isProcessing => quantityProcessing > 0;

  /// Dòng cần chú ý: cách ly, không bán được, hoặc dưới mức tồn tối thiểu.
  bool get needsAttention =>
      isQuarantined || isLowStock || lotIsSellable == false;

  factory InventoryStockLine.fromJson(Map<String, dynamic> json) {
    return InventoryStockLine(
      id: JsonReader.integer(json, 'id') ?? 0,
      warehouseId: JsonReader.integer(json, 'warehouseId') ?? 0,
      warehouseName: JsonReader.string(json, 'warehouseName'),
      locationId: JsonReader.integer(json, 'locationId'),
      locationCode: JsonReader.string(json, 'locationCode'),
      productVariantId: JsonReader.integer(json, 'productVariantId') ?? 0,
      sku: JsonReader.string(json, 'sku') ?? JsonReader.string(json, 'SKU'),
      productVariantName: JsonReader.string(json, 'productVariantName'),
      productName: JsonReader.string(json, 'productName'),
      categoryName: JsonReader.string(json, 'categoryName'),
      unitName: JsonReader.string(json, 'unitName'),
      unitWeightKg: JsonReader.decimal(json, 'unitWeightKg') ?? 0,
      isByproduct: JsonReader.boolean(json, 'isByproduct') ?? false,
      quantityOnHand: JsonReader.decimal(json, 'quantityOnHand') ?? 0,
      quantityReserved: JsonReader.decimal(json, 'quantityReserved') ?? 0,
      quantityAvailable: JsonReader.decimal(json, 'quantityAvailable') ?? 0,
      quantityQuarantine: JsonReader.decimal(json, 'quantityQuarantine') ??
          JsonReader.decimal(json, 'quarantinedKg') ??
          0,
      quantityProcessing: JsonReader.decimal(json, 'quantityProcessing') ?? 0,
      sellableOnHandKg: JsonReader.decimal(json, 'sellableOnHandKg') ?? 0,
      otherBlockedKg: JsonReader.decimal(json, 'otherBlockedKg') ?? 0,
      totalWeightKg: JsonReader.decimal(json, 'totalWeightKg') ?? 0,
      bags: JsonReader.integer(json, 'bags') ?? 0,
      openBags: JsonReader.integer(json, 'openBags') ?? 0,
      hasPhysicalBagData:
          JsonReader.boolean(json, 'hasPhysicalBagData') ?? false,
      minStockLevel: JsonReader.decimal(json, 'minStockLevel'),
      isLowStock: JsonReader.boolean(json, 'isLowStock') ?? false,
      paddyLotId: JsonReader.integer(json, 'paddyLotId'),
      lotCode: JsonReader.string(json, 'lotCode'),
      lotType: JsonReader.string(json, 'lotType'),
      lotStatusName: JsonReader.string(json, 'lotStatusName'),
      lotStatusColor: JsonReader.string(json, 'lotStatusColor'),
      lotQualityStatus: JsonReader.string(json, 'lotQualityStatus'),
      lotIsSellable: JsonReader.boolean(json, 'lotIsSellable'),
      lotInboundDate: _date(json, 'lotInboundDate'),
      lastStockTakeDate: _date(json, 'lastStockTakeDate'),
    );
  }
}

/// 5 chỉ số KPI đầu màn Kho, lấy từ `/api/v1/inventories/summary`.
class InventoryStockSummary {
  const InventoryStockSummary({
    this.totalOnHand = 0,
    this.totalAvailable = 0,
    this.totalReserved = 0,
    this.totalProcessing = 0,
    this.totalQuarantine = 0,
    this.lineCount = 0,
    this.quarantineLotCount = 0,
    this.lowStockCount = 0,
  });

  final double totalOnHand;
  final double totalAvailable;
  final double totalReserved;
  final double totalProcessing;
  final double totalQuarantine;
  final int lineCount;
  final int quarantineLotCount;
  final int lowStockCount;

  factory InventoryStockSummary.fromJson(Map<String, dynamic> json) {
    return InventoryStockSummary(
      totalOnHand: JsonReader.decimal(json, 'totalOnHand') ?? 0,
      totalAvailable: JsonReader.decimal(json, 'totalAvailable') ?? 0,
      totalReserved: JsonReader.decimal(json, 'totalReserved') ?? 0,
      totalProcessing: JsonReader.decimal(json, 'totalProcessing') ?? 0,
      totalQuarantine: JsonReader.decimal(json, 'totalQuarantine') ?? 0,
      lineCount: JsonReader.integer(json, 'lineCount') ?? 0,
      quarantineLotCount: JsonReader.integer(json, 'quarantineLotCount') ?? 0,
      lowStockCount: JsonReader.integer(json, 'lowStockCount') ?? 0,
    );
  }
}

/// Kho để đổ vào bộ lọc đầu màn.
class WarehouseOption {
  const WarehouseOption({required this.id, required this.name});

  final int id;
  final String name;

  factory WarehouseOption.fromJson(Map<String, dynamic> json) =>
      WarehouseOption(
        id: JsonReader.integer(json, 'id') ?? 0,
        name: JsonReader.string(json, 'name') ??
            JsonReader.string(json, 'warehouseName') ??
            'Kho',
      );
}

/// Gói dữ liệu một lần tải màn Kho.
class InventoryStockPage {
  const InventoryStockPage({
    required this.lines,
    required this.summary,
    required this.warehouses,
    required this.totalRecords,
    required this.loadedAt,
  });

  final List<InventoryStockLine> lines;
  final InventoryStockSummary summary;
  final List<WarehouseOption> warehouses;
  final int totalRecords;
  final DateTime loadedAt;

  bool get hasMore => lines.length < totalRecords;
}

DateTime? _date(Map<String, dynamic> json, String key) {
  final value = JsonReader.string(json, key);
  return value == null ? null : DateTime.tryParse(value)?.toLocal();
}
