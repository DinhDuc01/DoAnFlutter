import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/routes/app_routes.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/kho/data/kho_check_repository.dart';
import 'package:stocklite/features/kho/models/kho_check.dart';
import 'package:stocklite/features/kho/presentation/screens/kho_screen.dart';
import 'package:stocklite/features/products/data/product_variant_api.dart';
import 'package:stocklite/features/thu_mua/data/thu_mua_repository.dart';
import 'package:stocklite/features/thu_mua/models/thu_mua_receipt.dart';
import 'package:stocklite/features/thu_mua/models/purchase_schedule.dart';
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

      expect(find.text('Không tải được phiếu mua lúa'), findsOneWidget);
    });

    phoneTestWidgets('rejects zero bag weight', (tester) async {
      final repository = _ThuMuaRepository(Future.value(_inboundReceipt()));
      await tester.pumpWidget(
        MaterialApp(home: ThuMuaScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('thu_mua_bag_weight_0')),
        '0',
      );
      await tester.ensureVisible(find.text('Lưu phiếu mua'));
      await tester.tap(find.text('Lưu phiếu mua'));
      await tester.pump();

      expect(find.text('Khối lượng phải lớn hơn 0'), findsOneWidget);
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

      await _enterBagWeights(tester, const ['25', '25']);
      await tester.ensureVisible(find.text('Lưu phiếu mua'));
      await tester.tap(find.text('Lưu phiếu mua'));
      await tester.pumpAndSettle();

      expect(repository.confirmCount, 1);
      expect(repository.lastQuantity, 2);
      expect(repository.lastReceipt?.actualWeightKg, 50);
      expect(repository.lastReceipt?.bags.length, 2);
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
      await _enterBagWeights(tester, const ['50', '50']);
      final noteField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Ghi chú',
      );
      await tester.enterText(noteField, '  Lúa mới về  ');
      await tester.ensureVisible(find.text('Lưu phiếu mua'));
      await tester.tap(find.text('Lưu phiếu mua'));
      await tester.pumpAndSettle();

      expect(repository.lastReceipt?.productVariantId, 2);
      expect(repository.lastQuantity, 2);
      expect(repository.lastReceipt?.actualWeightKg, 100);
      expect(repository.lastReceipt?.bags.length, 2);
      expect(repository.lastNote, '  Lúa mới về  ');
      expect(find.text('Saved inbound'), findsOneWidget);
    });

    phoneTestWidgets('opens purchase draft from schedule without fake actuals',
        (tester) async {
      final repository = _ThuMuaRepository(
        Future.value(_inboundReceipt()),
      );
      final schedule = PurchaseSchedule(
        id: 42,
        farmerId: 1,
        riceVarietyId: 7,
        warehouseId: 9,
        warehouseName: 'Kho lúa 9',
        code: 'SCH-42',
        farmerName: 'Nông dân A',
        status: 'Đã xác nhận',
        riceVariety: 'ST25',
        scheduledAt: DateTime(2026, 8, 9),
        estimatedWeightKg: 120,
        expectedPrice: 6500,
        location: 'Ruộng A',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ThuMuaScreen(repository: repository, schedule: schedule),
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.thuMuaSuccess) {
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Schedule saved')),
              );
            }
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tạo phiếu mua lúa'), findsOneWidget);
      expect(find.text('Phiếu nhập kho'), findsNothing);
      expect(find.text('Từ lịch SCH-42'), findsOneWidget);
      expect(find.text('6500'), findsOneWidget);
      expect(find.textContaining('Dự kiến theo lịch: 120 kg'), findsOneWidget);
      expect(find.text('120.0'), findsNothing);
      expect(find.text('Chưa xác định sản phẩm'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('thu_mua_bag_weight_0')),
        '120',
      );
      await tester.ensureVisible(find.text('Lưu phiếu mua'));
      await tester.tap(find.text('Lưu phiếu mua'));
      await tester.pump();

      expect(repository.confirmCount, 0);
      expect(repository.defaultDraftCalls, 0);
      expect(find.textContaining('Vui lòng chọn sản phẩm'), findsOneWidget);
    });

    phoneTestWidgets('selects warehouse without default fallback',
        (tester) async {
      final repository = _ThuMuaRepository(
        Future.value(
          _inboundReceipt().copyWith(warehouseId: 0, warehouseName: ''),
        ),
        warehouses: const [
          ThuMuaWarehouse(id: 8, code: 'WH-8', name: 'Kho lúa'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ThuMuaScreen(repository: repository),
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.thuMuaSuccess) {
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Warehouse saved')),
              );
            }
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('thu_mua_warehouse')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Kho lúa').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lưu phiếu mua'));
      await tester.tap(find.text('Lưu phiếu mua'));
      await tester.pumpAndSettle();

      expect(repository.lastReceipt?.warehouseId, 8);
      expect(repository.lastReceipt?.warehouseName, 'Kho lúa');
      expect(find.text('Warehouse saved'), findsOneWidget);
    });

    phoneTestWidgets('changing product preserves independent form fields',
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
            costPrice: 9000,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ThuMuaScreen(repository: repository),
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.thuMuaSuccess) {
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Product saved')),
              );
            }
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('thu_mua_unit_price')),
        '12345',
      );
      await _enterBagWeights(tester, const ['20', '20', '20', '20']);
      await tester.enterText(
        find.byKey(const ValueKey('thu_mua_paid_amount')),
        '1000',
      );
      final noteField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Ghi chú',
      );
      await tester.enterText(noteField, 'Giữ ghi chú');

      await tester
          .ensureVisible(find.byKey(const ValueKey('inbound_product_1')));
      await tester.tap(find.byKey(const ValueKey('inbound_product_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Lúa thơm').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lưu phiếu mua'));
      await tester.tap(find.text('Lưu phiếu mua'));
      await tester.pumpAndSettle();

      expect(repository.lastReceipt?.productVariantId, 2);
      expect(repository.lastReceipt?.supplier?.id, 1);
      expect(repository.lastReceipt?.warehouseId, 2);
      expect(repository.lastReceipt?.actualWeightKg, 80);
      expect(repository.lastReceipt?.bags.length, 4);
      expect(repository.lastReceipt?.paidAmount, 1000);
      expect(repository.lastQuantity, 4);
      expect(repository.lastUnitCostPrice, 12345);
      expect(repository.lastNote, 'Giữ ghi chú');
      expect(find.text('Product saved'), findsOneWidget);
    });

    phoneTestWidgets('edit draft keeps receipt id and uses update action',
        (tester) async {
      final repository = _ThuMuaRepository(Future.value(_editReceipt()));
      await tester.pumpWidget(
        MaterialApp(
            home: ThuMuaScreen(repository: repository, draft: _editReceipt())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chỉnh sửa phiếu mua lúa'), findsOneWidget);
      final noteField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Ghi chú',
      );
      expect(tester.widget<TextField>(noteField).controller?.text,
          'Ghi chú draft');
      await tester.ensureVisible(find.text('Cập nhật phiếu mua'));
      await tester.tap(find.text('Cập nhật phiếu mua'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(repository.confirmCount, 1);
      expect(repository.lastReceipt?.id, 55);
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

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
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

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
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

Future<void> _enterBagWeights(
  WidgetTester tester,
  List<String> weights,
) async {
  for (var index = 0; index < weights.length; index += 1) {
    if (index > 0) {
      final addButton = find.widgetWithText(OutlinedButton, 'Thêm bao');
      await tester.ensureVisible(addButton);
      tester.widget<OutlinedButton>(addButton).onPressed?.call();
      await tester.pump();
    }
    final field = find.byKey(ValueKey('thu_mua_bag_weight_$index'));
    await tester.ensureVisible(field);
    await tester.enterText(field, weights[index]);
    await tester.pump();
  }
}

class _ThuMuaRepository implements ThuMuaRepository {
  _ThuMuaRepository(
    this.receipt, {
    this.products = const [],
    this.warehouses = const [
      ThuMuaWarehouse(id: 2, code: 'WH-2', name: 'Kho A'),
    ],
  });

  final Future<ThuMuaReceipt> receipt;
  final List<ProductVariantStock> products;
  final List<ThuMuaWarehouse> warehouses;
  int defaultDraftCalls = 0;
  int confirmCount = 0;
  int? lastQuantity;
  double? lastUnitCostPrice;
  String? lastNote;
  ThuMuaReceipt? lastReceipt;

  @override
  Future<ThuMuaReceipt> getDraftReceipt() {
    defaultDraftCalls += 1;
    return receipt;
  }

  @override
  Future<List<ProductVariantStock>> getSelectableProducts() async => products;

  @override
  Future<List<ThuMuaWarehouse>> getWarehouses() async => warehouses;

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
    lastUnitCostPrice = unitCostPrice;
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
    actualWeightKg: 25,
    moisturePercent: 14,
  );
}

ThuMuaReceipt _editReceipt() {
  return const ThuMuaReceipt(
    id: 55,
    productVariantId: 1,
    warehouseId: 2,
    warehouseName: 'Kho A',
    status: 'Phiếu nháp',
    productName: 'Gạo',
    sku: 'GAO',
    currentStock: 5,
    receiptCode: 'PPR-55',
    weightKg: 25,
    quantity: 1,
    noteHint: '',
    note: 'Ghi chú draft',
    unitCostPrice: 10000,
    supplier: ThuMuaSupplier(
      id: 1,
      code: 'SUP-01',
      name: 'Nhà cung cấp A',
    ),
    actualWeightKg: 25,
    moisturePercent: 14,
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
