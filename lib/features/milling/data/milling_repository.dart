import '../models/milling_order.dart';
import '../models/milling_location.dart';
import '../models/milling_output_form.dart';

/// Data boundary for the mobile milling completion workflow.
abstract class MillingRepository {
  Future<List<MillingFilterOption>> getMillingStatuses() async => const [];

  Future<List<MillingFilterOption>> getWarehouses() async => const [];

  Future<List<MillingProductOption>> getOutputProducts() async => const [];

  Future<List<MillingPaddyLotOption>> getPaddyLots() async => const [];

  Future<List<MillingLocation>> getLocations() async => const [];

  Future<List<MillingPutawaySuggestion>> getPutawaySuggestions({
    required int warehouseId,
    required int productVariantId,
    required double requiredWeightKg,
  }) async => const [];

  Future<MillingSourceSuggestion> getSourceSuggestion(int orderId) async =>
      const MillingSourceSuggestion(requiredWeightKg: 0, columns: []);

  Future<void> reserveOrder(
    int orderId,
    List<MillingSourceColumn> columns,
  ) async {
    throw UnsupportedError('Milling repository chưa hỗ trợ giữ lúa.');
  }

  Future<void> startOrder(int orderId) async {
    throw UnsupportedError('Milling repository chưa hỗ trợ bắt đầu xay.');
  }

  Future<int> createOrder({
    required int warehouseId,
    int? riceVarietyId,
    required double expectedYield,
    required double targetRiceKg,
    int? salesOrderId,
    MillingPaddyLotOption? lot,
    double? inputWeightKg,
    String? reason,
    double? moisturePercent,
    double? millingCost,
    double? incidentalCost,
    DateTime? expectedCompletionDate,
  }) async {
    throw UnsupportedError('Milling repository chưa hỗ trợ tạo lệnh.');
  }

  Future<void> updateOrder({
    required int id,
    required int warehouseId,
    int? riceVarietyId,
    required double expectedYield,
    required double targetRiceKg,
    int? salesOrderId,
    double? moisturePercent,
    double? millingCost,
    double? incidentalCost,
    DateTime? expectedCompletionDate,
    String? reason,
  }) async {
    throw UnsupportedError('Milling repository chưa hỗ trợ sửa lệnh.');
  }

  Future<MillingOrderPage> getMillingOrderPage({
    String search = '',
    int? statusId,
    int? warehouseId,
    int start = 0,
    int length = 20,
  }) async {
    final order = await getActiveOrder();
    return MillingOrderPage(
      orders: [order],
      recordsTotal: 1,
      recordsFiltered: 1,
    );
  }

  Future<List<MillingOrder>> getMillingOrders({
    String search = '',
    int? statusId,
    int? warehouseId,
  }) async {
    final page = await getMillingOrderPage(
      search: search,
      statusId: statusId,
      warehouseId: warehouseId,
    );
    return page.orders;
  }

  Future<MillingOrder> getMillingOrderDetail(int id) => getActiveOrder();

  Future<MillingOrder> getActiveOrder();

  Future<void> saveRiceBags(MillingOrder order);

  Future<void> saveBranBags(MillingOrder order);

  Future<void> completeOrder(
    MillingOrder order, {
    Map<String, int> outputLocationIds = const {},
    String? note,
    List<MillingOutputFormValue>? outputForms,
  });
}

/// Offline implementation used to exercise all screens before API wiring.
class MockMillingRepository implements MillingRepository {
  @override
  Future<List<MillingFilterOption>> getMillingStatuses() async => const [
        MillingFilterOption(id: 1, name: 'Nháp', code: 'DRAFT'),
        MillingFilterOption(id: 2, name: 'Đang xay', code: 'IN_PROGRESS'),
      ];

  @override
  Future<List<MillingFilterOption>> getWarehouses() async => const [
        MillingFilterOption(id: 1, name: 'Kho chứa 1', code: 'KHO-1'),
      ];

  @override
  Future<MillingSourceSuggestion> getSourceSuggestion(int orderId) async =>
      const MillingSourceSuggestion(requiredWeightKg: 0, columns: []);

  @override
  Future<void> reserveOrder(
      int orderId, List<MillingSourceColumn> columns) async {}

  @override
  Future<void> startOrder(int orderId) async {}

  @override
  Future<List<MillingPaddyLotOption>> getPaddyLots() async => const [];

  @override
  Future<List<MillingLocation>> getLocations() async => const [];

  @override
  Future<List<MillingPutawaySuggestion>> getPutawaySuggestions({
    required int warehouseId,
    required int productVariantId,
    required double requiredWeightKg,
  }) async => [
        const MillingPutawaySuggestion(
          locationId: 1,
          locationCode: 'K1-A01',
          zoneName: 'Khu A - Thành phẩm',
          currentOccupancyKg: 1000,
          maxCapacityKg: 10000,
          freeCapacityKg: 9000,
          isEmpty: false,
          reason: 'Vị trí gợi ý tự động (Top 1) sức chứa dư 9.000kg',
        ),
        const MillingPutawaySuggestion(
          locationId: 2,
          locationCode: 'K1-A02',
          zoneName: 'Khu A - Phụ phẩm',
          currentOccupancyKg: 500,
          maxCapacityKg: 5000,
          freeCapacityKg: 4500,
          isEmpty: false,
          reason: 'Vị trí gần khu vực xay xát',
        ),
      ];

  @override
  Future<int> createOrder({
    required int warehouseId,
    int? riceVarietyId,
    required double expectedYield,
    required double targetRiceKg,
    int? salesOrderId,
    MillingPaddyLotOption? lot,
    double? inputWeightKg,
    String? reason,
    double? moisturePercent,
    double? millingCost,
    double? incidentalCost,
    DateTime? expectedCompletionDate,
  }) async =>
      0;

  @override
  Future<void> updateOrder({
    required int id,
    required int warehouseId,
    int? riceVarietyId,
    required double expectedYield,
    required double targetRiceKg,
    int? salesOrderId,
    double? moisturePercent,
    double? millingCost,
    double? incidentalCost,
    DateTime? expectedCompletionDate,
    String? reason,
  }) async {}

  @override
  Future<MillingOrderPage> getMillingOrderPage({
    String search = '',
    int? statusId,
    int? warehouseId,
    int start = 0,
    int length = 20,
  }) async {
    final order = await getActiveOrder();
    final matchesSearch = search.trim().isEmpty ||
        order.millingCode.toLowerCase().contains(search.toLowerCase()) ||
        order.warehouseZone.toLowerCase().contains(search.toLowerCase()) ||
        order.scaleCode.toLowerCase().contains(search.toLowerCase());
    final matchesStatus = statusId == null || order.statusId == statusId;
    final matchesWarehouse =
        warehouseId == null || order.warehouseId == warehouseId;
    final orders = matchesSearch && matchesStatus && matchesWarehouse
        ? [order]
        : const <MillingOrder>[];
    return MillingOrderPage(
      orders: orders,
      recordsTotal: 1,
      recordsFiltered: orders.length,
    );
  }

  @override
  Future<List<MillingOrder>> getMillingOrders({
    String search = '',
    int? statusId,
    int? warehouseId,
  }) async {
    final page = await getMillingOrderPage(
      search: search,
      statusId: statusId,
      warehouseId: warehouseId,
    );
    return page.orders;
  }

  @override
  Future<MillingOrder> getMillingOrderDetail(int id) => getActiveOrder();

  @override
  Future<List<MillingProductOption>> getOutputProducts() async => const [
        MillingProductOption(
          id: 101,
          sku: 'RICE-001',
          name: 'Gạo thành phẩm',
          outputType: 'RICE',
          targetWeightKg: 50.0,
        ),
        MillingProductOption(
          id: 102,
          sku: 'BRAN-001',
          name: 'Cám',
          outputType: 'BRAN',
          targetWeightKg: 10.0,
        ),
        MillingProductOption(
          id: 103,
          sku: 'BROKEN-001',
          name: 'Tấm',
          outputType: 'BROKEN',
          targetWeightKg: 25.0,
        ),
      ];

  @override
  Future<MillingOrder> getActiveOrder() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    return MillingOrder(
      id: 21,
      millingCode: 'MO-2026-021',
      inputLotCode: 'IR50404',
      inputWeightKg: 5000,
      warehouseZone: 'Khu A',
      locationCode: 'Cột A03-A04',
      scaleCode: 'SCALE-03',
      statusId: 3,
      statusName: 'Đang xay',
      statusCode: 'MILLING',
      warehouseId: 1,
      warehouseName: 'Khu A',
      riceVarietyName: 'IR50404',
      yieldRateUsed: 0.65,
      totalRiceOutputKg: 3250,
      computedPaddyKg: 5000,
      createdDate: DateTime(2026, 8, 1),
      riceBags: List<MillingBag>.generate(
        10,
        (index) => MillingBag(index: index + 1, weightKg: 25),
      ),
      branBags: const [
        MillingBag(index: 1, weightKg: 20),
        MillingBag(index: 2, weightKg: 20),
        MillingBag(index: 3, weightKg: 19.5),
        MillingBag(index: 4, weightKg: 20),
        MillingBag(index: 5, weightKg: 20),
      ],
      riceProductVariantId: 101,
      branProductVariantId: 102,
      brokenProductVariantId: 103,
    );
  }

  @override
  Future<void> saveRiceBags(MillingOrder order) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> saveBranBags(MillingOrder order) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> completeOrder(
    MillingOrder order, {
    Map<String, int> outputLocationIds = const {},
    String? note,
    List<MillingOutputFormValue>? outputForms,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }
}
