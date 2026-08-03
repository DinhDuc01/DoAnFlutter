import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/routes/app_routes.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/giao_hang/data/giao_hang_repository.dart';
import 'package:stocklite/features/giao_hang/models/giao_hang_receipt.dart';
import 'package:stocklite/features/giao_hang/presentation/screens/giao_hang_screen.dart';
import 'package:stocklite/features/kho/data/kho_check_repository.dart';
import 'package:stocklite/features/kho/models/kho_check.dart';
import 'package:stocklite/features/kho/presentation/screens/kho_screen.dart';
import 'package:stocklite/features/products/data/product_variant_api.dart';
import 'package:stocklite/features/thu_mua/data/thu_mua_repository.dart';
import 'package:stocklite/features/thu_mua/models/thu_mua_receipt.dart';
import 'package:stocklite/features/thu_mua/presentation/screens/thu_mua_screen.dart';

void main() {
  setUp(() => AuthSessionStore.current = _session());
  tearDown(() => AuthSessionStore.current = null);

  group('ThuMuaScreen', () {
    phoneTestWidgets('shows loading while draft receipt is pending',
        (tester) async {
      final completer = Completer<ThuMuaReceipt>();
      await tester.pumpWidget(
        MaterialApp(
          home: ThuMuaScreen(repository: _ThuMuaRepository(completer.future)),
        ),
      );

      expect(find.text('Đang tải thông tin sản phẩm...'), findsOneWidget);
    });

    phoneTestWidgets('shows repository error', (tester) async {
      final completer = Completer<ThuMuaReceipt>();
      await tester.pumpWidget(
        MaterialApp(
          home: ThuMuaScreen(repository: _ThuMuaRepository(completer.future)),
        ),
      );
      completer.completeError('draft failed');
      await tester.pumpAndSettle();

      expect(find.text('Không tải được phiếu nhập kho'), findsOneWidget);
    });

    phoneTestWidgets('rejects zero inbound quantity', (tester) async {
      final repository = _ThuMuaRepository(Future.value(_inboundReceipt()));
      await tester.pumpWidget(
        MaterialApp(home: ThuMuaScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove));
      await tester.ensureVisible(find.text('Tạo phiếu chờ xác nhận'));
      await tester.tap(find.text('Tạo phiếu chờ xác nhận'));
      await tester.pump();

      expect(find.text('Số lượng nhập phải lớn hơn 0'), findsOneWidget);
      expect(repository.confirmCount, 0);
    });

    phoneTestWidgets('submits increased quantity and opens success route',
        (tester) async {
      final repository = _ThuMuaRepository(Future.value(_inboundReceipt()));
      Object? routeArguments;
      await tester.pumpWidget(
        MaterialApp(
          home: ThuMuaScreen(repository: repository),
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.thuMuaSuccess) {
              routeArguments = settings.arguments;
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Inbound success')),
              );
            }
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.ensureVisible(find.text('Tạo phiếu chờ xác nhận'));
      await tester.tap(find.text('Tạo phiếu chờ xác nhận'));
      await tester.pumpAndSettle();

      expect(repository.confirmCount, 1);
      expect(repository.lastQuantity, 2);
      expect(routeArguments, isA<ThuMuaSuccessResult>());
      expect(find.text('Inbound success'), findsOneWidget);
    });

    phoneTestWidgets('selects a product and submits quantity with note',
        (tester) async {
      final repository = _ThuMuaRepository(
        Future.value(_inboundReceipt()),
        products: const [
          ProductVariantStock(
            id: 1,
            name: 'Gạo',
            sku: 'GAO',
            weightKg: 25,
            quantityOnHand: 5,
            quantityReserved: 0,
            quantityAvailable: 5,
          ),
          ProductVariantStock(
            id: 2,
            name: 'Lúa thơm',
            sku: 'LUA-THOM',
            weightKg: 50,
            quantityOnHand: 8,
            quantityReserved: 0,
            quantityAvailable: 8,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ThuMuaScreen(repository: repository),
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.thuMuaSuccess) {
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Saved inbound')),
              );
            }
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('inbound_product_1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Lúa thơm').last);
      await tester.pumpAndSettle();

      expect(find.text('Lúa thơm'), findsWidgets);
      await tester.tap(find.byIcon(Icons.add));
      final noteField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Ghi chú',
      );
      await tester.enterText(noteField, '  Lúa mới về  ');
      await tester.ensureVisible(find.text('Tạo phiếu chờ xác nhận'));
      await tester.tap(find.text('Tạo phiếu chờ xác nhận'));
      await tester.pumpAndSettle();

      expect(repository.lastReceipt?.productVariantId, 2);
      expect(repository.lastQuantity, 2);
      expect(repository.lastNote, '  Lúa mới về  ');
      expect(find.text('Saved inbound'), findsOneWidget);
    });
  });

  group('GiaoHangScreen', () {
    phoneTestWidgets('shows loading and repository error states',
        (tester) async {
      final receiptCompleter = Completer<GiaoHangReceipt>();
      final repository = _GiaoHangRepository(
        receipt: receiptCompleter.future,
        customers: Future.value(const []),
      );
      await tester.pumpWidget(
        MaterialApp(home: GiaoHangScreen(repository: repository)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      receiptCompleter.completeError('delivery failed');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Không tải được màn bán hàng'),
        findsOneWidget,
      );
    });

    phoneTestWidgets('requires customer before confirmation', (tester) async {
      final repository = _GiaoHangRepository(
        receipt: Future.value(_deliveryReceipt()),
        customers: Future.value(const []),
      );
      await tester.pumpWidget(
        MaterialApp(home: GiaoHangScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      final confirmButton = find.text('Tạo đơn chờ xác nhận');
      await tester.scrollUntilVisible(
        confirmButton,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(confirmButton);
      await tester.pump();

      expect(find.text('Vui lòng chọn khách hàng nhận hàng.'), findsOneWidget);
      expect(repository.confirmCount, 0);
    });

    phoneTestWidgets('submits delivery and passes result to success route',
        (tester) async {
      final repository = _GiaoHangRepository(
        receipt: Future.value(_deliveryReceipt()),
        customers: Future.value(const [
          GiaoHangCustomer(id: 1, code: 'KH-01', name: 'Khách A'),
        ]),
      );
      Object? routeArguments;
      await tester.pumpWidget(
        MaterialApp(
          home: GiaoHangScreen(repository: repository),
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.giaoHangSuccess) {
              routeArguments = settings.arguments;
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Delivery success')),
              );
            }
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();
      final confirmButton = find.text('Tạo đơn chờ xác nhận');
      await tester.scrollUntilVisible(
        confirmButton,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(repository.confirmCount, 1);
      expect(repository.lastQuantity, 1);
      expect(routeArguments, isA<GiaoHangSuccessResult>());
      expect(find.text('Delivery success'), findsOneWidget);
    });
  });

  group('KhoScreen', () {
    phoneTestWidgets('shows loading and repository error states',
        (tester) async {
      final completer = Completer<KhoCheck>();
      await tester.pumpWidget(
        MaterialApp(
            home: KhoScreen(repository: _KhoRepository(completer.future))),
      );
      expect(find.text('Đang tải phiếu kiểm kê...'), findsOneWidget);

      completer.completeError('stocktake failed');
      await tester.pumpAndSettle();
      expect(find.text('Không tải được dữ liệu tồn kho'), findsOneWidget);
    });

    phoneTestWidgets('requires actual quantity for every product',
        (tester) async {
      final repository = _KhoRepository(Future.value(_stockCheck()));
      await tester.pumpWidget(
        MaterialApp(home: KhoScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tạo phiếu kiểm kê'));
      await tester.pump();

      expect(
        find.text('Vui lòng nhập số lượng thực tế cho tất cả sản phẩm.'),
        findsOneWidget,
      );
      expect(repository.createCount, 0);
    });

    phoneTestWidgets('submits entered stocktake quantity', (tester) async {
      final repository = _KhoRepository(Future.value(_stockCheck()));
      await tester.pumpWidget(
        MaterialApp(home: KhoScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('actual_1_3')),
        '15',
      );
      await tester.tap(find.text('Tạo phiếu kiểm kê'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.createCount, 1);
      expect(repository.lastItems.single.actualQuantity, 15);
      expect(find.text('Đã tạo phiếu kiểm kê'), findsOneWidget);
      expect(find.text('Mã phiếu backend: #77'), findsOneWidget);
    });
  });
}

void phoneTestWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await callback(tester);
  });
}

class _ThuMuaRepository implements ThuMuaRepository {
  _ThuMuaRepository(this.receipt, {this.products = const []});
  final Future<ThuMuaReceipt> receipt;
  final List<ProductVariantStock> products;
  int confirmCount = 0;
  int? lastQuantity;
  String? lastNote;
  ThuMuaReceipt? lastReceipt;

  @override
  Future<ThuMuaReceipt> getDraftReceipt() => receipt;

  @override
  Future<List<ProductVariantStock>> getSelectableProducts() async => products;

  @override
  Future<ThuMuaReceipt> getDraftReceiptForProduct(
    ProductVariantStock product,
  ) async {
    final initial = await receipt;
    return ThuMuaReceipt(
      productVariantId: product.id,
      warehouseId: initial.warehouseId,
      warehouseName: initial.warehouseName,
      status: initial.status,
      productName: product.name,
      sku: product.sku,
      currentStock: product.quantityOnHand,
      receiptCode: initial.receiptCode,
      weightKg: product.weightKg,
      quantity: 1,
      noteHint: initial.noteHint,
      unitCostPrice: product.costPrice > 0 ? product.costPrice : 10000,
      supplier: initial.supplier,
      expectedDate: initial.expectedDate,
    );
  }

  @override
  Future<List<ThuMuaSupplier>> getSuppliers() async => const [
        ThuMuaSupplier(id: 1, code: 'SUP-01', name: 'Nhà cung cấp A'),
      ];

  @override
  Future<ThuMuaOrderSubmission> confirmInbound({
    required ThuMuaReceipt receipt,
    required int quantity,
    required double unitCostPrice,
    required String note,
  }) async {
    confirmCount++;
    lastReceipt = receipt;
    lastQuantity = quantity;
    lastNote = note;
    return const ThuMuaOrderSubmission(
      id: 10,
      code: 'PO-10',
      status: 'Chờ xác nhận',
    );
  }

  @override
  Future<void> confirmPurchaseOrder(int orderId) async {}
}

class _GiaoHangRepository implements GiaoHangRepository {
  _GiaoHangRepository({required this.receipt, required this.customers});
  final Future<GiaoHangReceipt> receipt;
  final Future<List<GiaoHangCustomer>> customers;
  int confirmCount = 0;
  int? lastQuantity;

  @override
  Future<List<GiaoHangReceipt>> getAvailableReceipts() async => [await receipt];
  @override
  Future<GiaoHangReceipt> getDraftReceipt() => receipt;
  @override
  Future<List<GiaoHangCustomer>> getCustomers() => customers;
  @override
  Future<SalesOrderSubmission> confirmOutbound({
    required GiaoHangReceipt receipt,
    required int quantity,
    required double unitSalePrice,
    required DateTime? expectedDeliveryDate,
    required String shippingAddress,
    required String note,
  }) async {
    confirmCount++;
    lastQuantity = quantity;
    return const SalesOrderSubmission(
      id: 20,
      code: 'SO-20',
      status: 'Chờ xác nhận',
    );
  }

  @override
  Future<void> confirmSalesOrder(int orderId) async {}
}

class _KhoRepository implements KhoCheckRepository {
  _KhoRepository(this.check);
  final Future<KhoCheck> check;
  int createCount = 0;
  List<KhoCheckItem> lastItems = const [];

  @override
  Future<KhoCheck> getDraftCheck() => check;

  @override
  Future<int> createStockTake({
    required KhoCheck check,
    required List<KhoCheckItem> items,
    String? note,
  }) async {
    createCount++;
    lastItems = items;
    return 77;
  }
}

ThuMuaReceipt _inboundReceipt() {
  return ThuMuaReceipt(
    productVariantId: 1,
    warehouseId: 2,
    warehouseName: 'Kho A',
    status: 'Nhập kho',
    productName: 'Gạo',
    sku: 'GAO',
    currentStock: 5,
    receiptCode: 'PN-01',
    weightKg: 25,
    quantity: 1,
    noteHint: '',
    unitCostPrice: 10000,
    supplier: const ThuMuaSupplier(
      id: 1,
      code: 'SUP-01',
      name: 'Nhà cung cấp A',
    ),
    expectedDate: DateTime(2026, 7, 30),
  );
}

GiaoHangReceipt _deliveryReceipt() {
  return GiaoHangReceipt(
    productVariantId: 1,
    warehouseId: 2,
    warehouseName: 'Kho A',
    status: 'Sẵn sàng giao',
    productName: 'Gạo',
    sku: 'GAO',
    currentStock: 5,
    receiptCode: 'GH-01',
    quantity: 1,
    noteHint: '',
    unitSalePrice: 15000,
    expectedDeliveryDate: DateTime(2026, 7, 30),
    shippingAddress: 'Cần Thơ',
  );
}

KhoCheck _stockCheck() {
  return KhoCheck(
    warehouseId: 1,
    checkCode: 'ST-01',
    warehouseName: 'Kho A',
    noteHint: '',
    checkedAt: DateTime(2026),
    items: const [
      KhoCheckItem(
        productVariantId: 1,
        productName: 'Gạo',
        sku: 'GAO',
        systemQuantity: 10,
        locationId: 3,
      ),
    ],
  );
}

AuthSession _session() {
  return const AuthSession(
    accessToken: 'token',
    refreshToken: 'refresh',
    user: AuthUser(id: 1, fullName: 'Tester', email: 'tester@example.com'),
  );
}
