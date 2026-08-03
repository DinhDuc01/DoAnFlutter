import '../../products/data/product_variant_api.dart';
import '../models/thu_mua_receipt.dart';

/// Repository cho luong nhap kho tren mobile.
abstract class ThuMuaRepository {
  /// Lay phieu nhap kho nhap de hien thi tren form.
  Future<ThuMuaReceipt> getDraftReceipt();

  /// Products that can be selected when creating an inbound adjustment.
  Future<List<ProductVariantStock>> getSelectableProducts() async => const [];

  Future<List<ThuMuaSupplier>> getSuppliers() async => const [];

  /// Builds the draft for the product explicitly selected by the operator.
  Future<ThuMuaReceipt> getDraftReceiptForProduct(
    ProductVariantStock product,
  ) {
    return getDraftReceipt();
  }

  /// Goi backend de cong them so luong vao ton kho.
  Future<ThuMuaOrderSubmission> confirmInbound({
    required ThuMuaReceipt receipt,
    required int quantity,
    required double unitCostPrice,
    required String note,
  });

  Future<void> confirmPurchaseOrder(int orderId);
}
