import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/widgets/app_ui.dart';
import 'package:stocklite/features/inbound/data/inbound_order_repository.dart';
import 'package:stocklite/features/inbound/models/inbound_order.dart';
import 'package:stocklite/features/inbound/presentation/screens/inbound_putaway_screen.dart';
import 'package:stocklite/features/quality_inspection/data/quality_inspection_repository.dart';
import 'package:stocklite/features/quality_inspection/models/quality_inspection.dart';
import 'package:stocklite/features/quality_inspection/presentation/screens/quality_inspection_screen.dart';

/// Hai màn Chất lượng và Nhập kho KHÔNG còn hàng ô thống kê (KPI) trên mobile —
/// màn hình hẹp nên ưu tiên danh sách. Test giữ lại để chặn hồi quy hai việc:
/// 1. Không ai thêm lại ô thống kê vào hai màn này.
/// 2. Nội dung còn lại không tràn ở máy hẹp + cỡ chữ hệ thống lớn.
void main() {
  /// Máy hẹp 320dp + cỡ chữ hệ thống 1.3× — điều kiện dễ tràn nhất.
  Future<void> pumpNarrow(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: screen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('màn Chất lượng bỏ ô thống kê và không tràn trên máy hẹp',
      (tester) async {
    await pumpNarrow(
      tester,
      QualityInspectionScreen(
        repository: _QualityRepository(
          items: [
            QualityInspection(
              id: 1,
              paddyLotId: 2,
              lotCode: 'LOT-0001',
              lotStatusCode: 'IN_STOCK',
              inspectedAt: DateTime(2026, 8, 15),
              passedInspection: true,
              moisturePercent: 13.5,
            ),
          ],
          recordsFiltered: 1234,
        ),
      ),
    );

    expect(find.byType(AppStatTile), findsNothing);
    expect(find.text('LOT-0001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('màn Nhập kho bỏ ô thống kê và không tràn trên máy hẹp',
      (tester) async {
    await pumpNarrow(
      tester,
      InboundPutawayScreen(
        repository: _InboundRepository(
          lines: const [
            InboundPutawayLine(
              order: InboundOrder(
                id: 1,
                poCode: 'PO-0001',
                warehouseId: 3,
                warehouseName: 'Kho A',
                statusName: 'Đã duyệt',
                statusCode: 'Approved',
                sourceType: 'RECEIPT',
              ),
              item: InboundOrderItem(
                id: 11,
                inboundOrderId: 1,
                quantityOrdered: 123456.78,
                quantityReceived: 0,
                receiptStatus: 'Pending',
                paddyLotCode: 'LOT-0001',
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.byType(AppStatTile), findsNothing);
    // Khối lượng dài nhất (có dấu phân cách nghìn) vẫn phải vừa thẻ lô.
    expect(find.textContaining('123.456,78 kg'), findsOneWidget);
    expect(find.text('Lô chờ nhập kho (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _QualityRepository implements QualityInspectionRepository {
  _QualityRepository({required this.items, required this.recordsFiltered});

  final List<QualityInspection> items;
  final int recordsFiltered;

  @override
  Future<QualityInspectionPage> loadPage({
    int page = 1,
    int pageSize = 10,
    String search = '',
    bool? passedInspection,
  }) async =>
      QualityInspectionPage(
        items: items,
        recordsTotal: recordsFiltered,
        recordsFiltered: recordsFiltered,
      );

  @override
  Future<QualityInspection> getDetail(int id) async => items.first;

  @override
  Future<List<QualityInspection>> getHistory(int paddyLotId) async => items;

  @override
  Future<QualityLot> getLot(int paddyLotId) async =>
      const QualityLot(id: 2, lotCode: 'LOT-0001');

  @override
  Future<Map<int, QualityLot>> loadLotMap() async => const <int, QualityLot>{
        2: QualityLot(
          id: 2,
          lotCode: 'LOT-0001',
          productVariantName: 'Lúa OM5451',
          warehouseName: 'Kho A',
          initialWeightKg: 123456.78,
        ),
      };

  @override
  Future<void> update(QualityInspectionUpdate payload) async =>
      throw StateError('Test không được ghi dữ liệu.');
}

class _InboundRepository implements InboundOrderRepository {
  _InboundRepository({required this.lines});

  final List<InboundPutawayLine> lines;

  @override
  Future<List<InboundPutawayLine>> getPutawayPending() async => lines;

  @override
  Future<List<StorageLocation>> getLocations() async => const [
        StorageLocation(
          id: 1,
          warehouseId: 3,
          zoneName: 'A',
          isActive: true,
          slotCode: 'A-01',
          maxCapacity: 5000,
          currentOccupancy: 1000,
        ),
      ];

  @override
  Future<void> submit(int orderId) async {}

  @override
  Future<void> startReceipt(int orderId, int itemId) async {}

  @override
  Future<void> recordQuantity(
    int orderId,
    int itemId,
    double quantityReceived,
  ) async {}

  @override
  Future<List<PutawaySuggestion>> getPutawaySuggestions(
    int orderId,
    int itemId,
  ) async =>
      const <PutawaySuggestion>[];

  @override
  Future<BagPutawayPlan?> getBagPutawayPlan(int orderId, int itemId) async =>
      null;

  @override
  Future<void> selectPutaway(
    int orderId,
    int itemId, {
    required int locationId,
    required bool isOverride,
    String? overrideReason,
    double? weightKg,
  }) async {}

  @override
  Future<void> confirmReceipt(
    int orderId,
    int itemId, {
    required String operationKey,
    List<BagPutawayColumn>? columns,
  }) async {}
}
