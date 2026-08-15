import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/milling/data/milling_repository.dart';
import 'package:stocklite/features/milling/models/milling_order.dart';
import 'package:stocklite/features/milling/presentation/screens/milling_preparation_screen.dart';
import 'package:stocklite/features/milling/presentation/screens/milling_source_selection_screen.dart';

/// Ma trận hành động của màn xay xát phải khớp web:
/// - Nháp: Sửa lệnh · Hủy lệnh · Giữ lúa
/// - Đã giữ lúa: Phân bổ lại lúa · Hủy lệnh · Bắt đầu xay
/// - Đang xay: Xem nguồn lúa (chỉ đọc) · Nhập kết quả xay
void main() {
  Future<void> openDetail(WidgetTester tester, MillingRepository repo) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: MillingPreparationScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('MO-21').first);
    await tester.pumpAndSettle();
  }

  testWidgets('a draft order offers edit, cancel and reserve', (tester) async {
    await openDetail(tester, _ActionRepository(statusCode: 'DRAFT'));

    expect(find.widgetWithText(OutlinedButton, 'Sửa lệnh'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Hủy lệnh'), findsOneWidget);
    expect(find.text('Giữ lúa'), findsOneWidget);
    expect(find.text('Bắt đầu xay'), findsNothing);
  });

  testWidgets('a reserved order can be re-allocated, cancelled or started',
      (tester) async {
    await openDetail(tester, _ActionRepository(statusCode: 'RESERVED'));

    // Web cho phân bổ lại lúa khi lệnh đã giữ — mobile phải có nút này.
    expect(find.widgetWithText(OutlinedButton, 'Phân bổ lại lúa'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Hủy lệnh'), findsOneWidget);
    expect(find.text('Bắt đầu xay'), findsOneWidget);
    expect(find.text('Giữ lúa'), findsNothing);
  });

  testWidgets('cancelling asks for confirmation then calls the API',
      (tester) async {
    final repository = _ActionRepository(statusCode: 'RESERVED');
    await openDetail(tester, repository);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Hủy lệnh'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sẽ được giải phóng'), findsOneWidget);
    expect(repository.cancelCalls, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Hủy lệnh'));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, [21]);
  });

  testWidgets('a milling order only exposes a read-only source view',
      (tester) async {
    await openDetail(tester, _ActionRepository(statusCode: 'IN_PROGRESS'));

    expect(find.widgetWithText(OutlinedButton, 'Xem nguồn lúa'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Hủy lệnh'), findsNothing);
    expect(find.byKey(const Key('milling_enter_output_button')), findsOneWidget);
  });

  group('MillingSourceSelectionScreen', () {
    Widget app(String statusCode, {bool readOnly = false}) => MaterialApp(
          home: MillingSourceSelectionScreen(
            order: _order(statusCode),
            repository: _SourceRepository(),
            readOnly: readOnly,
          ),
        );

    testWidgets('reserved order relabels the action as re-allocate',
        (tester) async {
      await tester.pumpWidget(app('RESERVED'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Phân bổ lại lúa'), findsOneWidget);
      expect(find.text('Tự động chọn nguồn phù hợp'), findsOneWidget);
    });

    testWidgets('milling order locks the source and hides every action',
        (tester) async {
      await tester.pumpWidget(app('IN_PROGRESS', readOnly: true));
      await tester.pumpAndSettle();

      expect(find.textContaining('đã khóa nguồn lúa'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Tự động chọn nguồn phù hợp'), findsNothing);
      // Ô tick bao vẫn hiện để xem nhưng không bấm được.
      final tiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(tiles, isNotEmpty);
      expect(tiles.every((tile) => tile.onChanged == null), isTrue);
    });
  });
}

MillingOrder _order(String statusCode) => MillingOrder(
      id: 21,
      millingCode: 'MO-21',
      inputLotCode: 'LOT-01',
      inputWeightKg: 100,
      warehouseZone: 'Kho A',
      locationCode: 'A01',
      scaleCode: 'Cân thủ công',
      riceBags: const [],
      branBags: const [],
      statusCode: statusCode,
      statusName: statusCode,
      warehouseId: 7,
      riceVarietyName: 'OM5451',
    );

class _ActionRepository extends MockMillingRepository {
  _ActionRepository({required this.statusCode});

  final String statusCode;
  final List<int> cancelCalls = <int>[];

  @override
  Future<MillingOrderPage> getMillingOrderPage({
    String search = '',
    int? statusId,
    int? warehouseId,
    int start = 0,
    int length = 20,
  }) async =>
      MillingOrderPage(
        orders: [_order(statusCode)],
        recordsTotal: 1,
        recordsFiltered: 1,
      );

  @override
  Future<MillingOrder> getMillingOrderDetail(int id) async => _order(statusCode);

  @override
  Future<MillingSourceSuggestion> getSourceSuggestion(int orderId) async =>
      const MillingSourceSuggestion(requiredWeightKg: 100, columns: []);

  @override
  Future<void> cancelOrder(int orderId) async {
    cancelCalls.add(orderId);
  }
}

class _SourceRepository extends MockMillingRepository {
  @override
  Future<MillingSourceSuggestion> getSourceSuggestion(int orderId) async =>
      const MillingSourceSuggestion(
        requiredWeightKg: 100,
        columns: [
          MillingSourceColumn(
            locationId: 12,
            locationCode: 'A01',
            bags: [
              MillingSourceBag(
                id: 101,
                bagNo: 1,
                weightKg: 60,
                status: 'STORED',
                selected: true,
              ),
              MillingSourceBag(
                id: 102,
                bagNo: 2,
                weightKg: 60,
                status: 'STORED',
                selected: true,
              ),
            ],
          ),
        ],
      );
}
