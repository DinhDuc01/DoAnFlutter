import '../models/kho_check.dart';

/// Hợp đồng đọc tồn và tạo phiếu kiểm kê (StockTake).
abstract class KhoCheckRepository {
  /// Tạo dữ liệu phiếu kiểm kê nháp từ tồn kho hiện tại.
  Future<KhoCheck> getDraftCheck();

  Future<int> createStockTake({
    required KhoCheck check,
    required List<KhoCheckItem> items,
    String? note,
  });
}
