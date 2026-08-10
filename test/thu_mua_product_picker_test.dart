import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/products/data/product_variant_api.dart';
import 'package:stocklite/features/thu_mua/data/thu_mua_repository.dart';
import 'package:stocklite/features/thu_mua/models/thu_mua_receipt.dart';
import 'package:stocklite/features/thu_mua/presentation/screens/thu_mua_screen.dart';

void main() {
  testWidgets('the add flow selects a product from the backend product list',
      (tester) async {
    final repository = _ThuMuaPickerRepository();

    await tester.pumpWidget(
      MaterialApp(home: ThuMuaScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('inbound_product_1')));
    await tester.pumpAndSettle();

    expect(find.text('Chọn sản phẩm cần thu mua'), findsOneWidget);
    expect(find.text('Lúa thơm'), findsOneWidget);
    expect(find.textContaining('LUA-THOM · Tồn hiện tại 8 kg'), findsOneWidget);

    await tester.tap(find.text('Lúa thơm'));
    await tester.pumpAndSettle();

    expect(repository.selectedProductId, 2);
    expect(find.textContaining('Lúa thơm · LUA-THOM'), findsOneWidget);
  });
}

class _ThuMuaPickerRepository implements ThuMuaRepository {
  static const supplier = ThuMuaSupplier(
    id: 1,
    code: 'NCC-01',
    name: 'Nhà cung cấp A',
  );

  static const products = [
    ProductVariantStock(
      id: 1,
      name: 'Gạo',
      sku: 'GAO',
      weightKg: 25,
      quantityOnHand: 5,
      quantityReserved: 0,
      quantityAvailable: 5,
      costPrice: 12000,
    ),
    ProductVariantStock(
      id: 2,
      name: 'Lúa thơm',
      sku: 'LUA-THOM',
      weightKg: 50,
      quantityOnHand: 8,
      quantityReserved: 0,
      quantityAvailable: 8,
      costPrice: 9000,
    ),
  ];

  int? selectedProductId;

  @override
  Future<ThuMuaReceipt> getDraftReceipt() =>
      getDraftReceiptForProduct(products.first);

  @override
  Future<List<ProductVariantStock>> getSelectableProducts() async => products;

  @override
  Future<List<ThuMuaSupplier>> getSuppliers() async => const [supplier];

  @override
  Future<ThuMuaReceipt> getDraftReceiptForProduct(
    ProductVariantStock product,
  ) async {
    selectedProductId = product.id;
    return ThuMuaReceipt(
      productVariantId: product.id,
      warehouseId: 1,
      warehouseName: 'Kho chính',
      status: 'Chờ xác nhận',
      productName: product.name,
      sku: product.sku,
      currentStock: product.quantityOnHand,
      receiptCode: 'PO-DRAFT',
      weightKg: product.weightKg,
      quantity: 1,
      noteHint: '',
      unitCostPrice: product.costPrice,
      supplier: supplier,
      expectedDate: DateTime(2026, 7, 27),
    );
  }

  @override
  Future<ThuMuaOrderSubmission> confirmInbound({
    required ThuMuaReceipt receipt,
    required int quantity,
    required double unitCostPrice,
    required String note,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> confirmPurchaseOrder(int orderId) async {}
}
