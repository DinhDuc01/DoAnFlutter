import '../../kho/models/inventory_stock.dart';
import '../models/stock_take.dart';

abstract class StockTakeRepository {
  Future<StockTakePage> getStockTakesPaged({
    required int start,
    required int length,
    String? search,
    int? warehouseId,
    String? statusCode,
  });

  Future<StockTakeDetail> getStockTakeDetail(int id);

  Future<List<WarehouseOption>> getWarehouses();
}
