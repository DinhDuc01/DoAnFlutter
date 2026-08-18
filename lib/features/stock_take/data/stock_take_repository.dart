import '../../kho/models/inventory_stock.dart';
import '../models/stock_take.dart';
import '../../kho/models/stock_take.dart' as legacy;
import '../../kho/data/stock_take_repository.dart'
    show StockTakeScope, StockTakeScopeX, StockTakeLocationOption;
export '../../kho/data/stock_take_repository.dart'
    show StockTakeScope, StockTakeScopeX, StockTakeLocationOption;

class StockTakeOption {
  const StockTakeOption({
    required this.id,
    required this.code,
    required this.label,
  });

  final int id;
  final String code;
  final String label;
}

class StockTakeStatusOption {
  const StockTakeStatusOption({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;
}

abstract class StockTakeRepository {
  Future<StockTakePage> getStockTakesPaged({
    required int start,
    required int length,
    String? search,
    int? warehouseId,
    String? statusCode,
  });

  Future<legacy.StockTakeDetail> getStockTakeDetail(int id);
  Future<List<WarehouseOption>> getWarehouses();
  Future<List<StockTakeStatusOption>> getStatuses();
  Future<List<StockTakeLocationOption>> getLocations(int warehouseId);
  Future<List<StockTakeOption>> getLots();
  Future<List<StockTakeOption>> getSkus();

  Future<int> create({
    required int warehouseId,
    required StockTakeScope scope,
    String? zoneName,
    int? locationId,
    int? paddyLotId,
    int? productVariantId,
    String? lotCode,
    String? skuCode,
    String? note,
  });

  Future<void> saveCounts(int id, List<legacy.StockTakeLine> lines, {String? note});
  Future<void> submit(int id, {String? note});
  Future<legacy.ScanBagResult> scanBag(int id, String qrCode);
}
