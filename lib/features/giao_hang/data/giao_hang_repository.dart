import '../models/giao_hang_receipt.dart';

abstract class GiaoHangRepository {
  Future<List<GiaoHangReceipt>> getAvailableReceipts();
  Future<GiaoHangReceipt> getDraftReceipt();
  Future<List<GiaoHangCustomer>> getCustomers();

  Future<SalesOrderSubmission> confirmOutbound({
    required GiaoHangReceipt receipt,
    required int quantity,
    required double unitSalePrice,
    required DateTime? expectedDeliveryDate,
    required String shippingAddress,
    required String note,
  });

  Future<void> confirmSalesOrder(int orderId);
}
