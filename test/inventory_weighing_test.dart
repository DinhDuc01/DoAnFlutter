import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/products/data/product_variant_api.dart';
import 'package:stocklite/features/scale/data/inventory_weighing_repository.dart';
import 'package:stocklite/features/scale/models/inventory_weighing_result.dart';
import 'package:stocklite/features/scale/models/weight_reading.dart';
import 'package:stocklite/features/scale/presentation/screens/inventory_weighing_screen.dart';

void main() {
  testWidgets('loads warehouse products and records a manual weight',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryWeighingScreen(
          repository: _Repository([_product()]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Gạo ST25'), findsWidgets);
    expect(find.textContaining('Còn 3'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('increase_weighing_quantity')));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('manual_weight')),
      '99.5',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm_weighing')),
    );
    await tester.tap(find.byKey(const ValueKey('confirm_weighing')));
    await tester.pumpAndSettle();

    expect(find.text('Đã ghi nhận kết quả cân'), findsOneWidget);
    expect(find.text('99.500 kg'), findsOneWidget);
    expect(find.text('49.750 kg/sp'), findsOneWidget);
    expect(find.text(WeighingMethod.manual.label), findsWidgets);
  });

  testWidgets('uses a stable result returned by the IoT scale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryWeighingScreen(
          repository: _Repository([_product()]),
          iotReadingPicker: (_) async => WeightReading(
            weight: 50.125,
            unit: 'kg',
            isStable: true,
            receivedAt: DateTime(2026),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cân IoT'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('read_iot_scale')));
    await tester.pumpAndSettle();

    expect(find.text('50.125 kg'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm_weighing')),
    );
    await tester.tap(find.byKey(const ValueKey('confirm_weighing')));
    await tester.pumpAndSettle();

    expect(find.text('Đã ghi nhận kết quả cân'), findsOneWidget);
    expect(find.text(WeighingMethod.iot.label), findsWidgets);
  });

  testWidgets('shows loading, error and empty stock states', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryWeighingScreen(
          repository: _Repository.error('inventory failed'),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.textContaining('inventory failed'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: InventoryWeighingScreen(
          key: const ValueKey('empty-stock'),
          repository: _Repository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kho chưa có sản phẩm khả dụng để cân.'), findsOneWidget);
  });

  testWidgets('long product names do not overflow on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: InventoryWeighingScreen(
          repository: _Repository([
            _longProduct(),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _Repository implements InventoryWeighingRepository {
  _Repository(this.products) : error = null;
  _Repository.error(this.error) : products = const [];

  final List<ProductVariantStock> products;
  final Object? error;

  @override
  Future<List<ProductVariantStock>> loadProductsInStock() async {
    if (error != null) throw error!;
    return products;
  }
}

ProductVariantStock _product() {
  return const ProductVariantStock(
    id: 1,
    name: 'Gạo ST25 - Bao 50kg',
    sku: 'GAO-ST25',
    weightKg: 50,
    quantityOnHand: 3,
    quantityReserved: 0,
    quantityAvailable: 3,
    unitName: 'bao',
    warehouses: [
      WarehouseInventory(
        inventoryId: 1,
        warehouseId: 2,
        warehouseName: 'Kho chính',
        quantityOnHand: 3,
        quantityReserved: 0,
        quantityAvailable: 3,
      ),
    ],
  );
}

ProductVariantStock _longProduct() {
  return const ProductVariantStock(
    id: 2,
    name: 'Nhà cung cấp Apple Nhật Minh - phụ phẩm đóng bao loại đặc biệt',
    sku: 'PV-PHUPHAM-APPLE-NHAT-MINH-2026',
    weightKg: 50,
    quantityOnHand: 100,
    quantityReserved: 0,
    quantityAvailable: 100,
    unitName: 'bao',
    warehouses: [
      WarehouseInventory(
        inventoryId: 2,
        warehouseId: 2,
        warehouseName: 'Kho chứa phụ phẩm Apple Nhật Minh khu vực phía Bắc',
        quantityOnHand: 100,
        quantityReserved: 0,
        quantityAvailable: 100,
      ),
    ],
  );
}
