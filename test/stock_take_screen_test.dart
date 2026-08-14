import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/kho/data/stock_take_repository.dart';
import 'package:stocklite/features/kho/models/inventory_stock.dart'
    show WarehouseOption;
import 'package:stocklite/features/kho/models/stock_take.dart';
import 'package:stocklite/features/kho/presentation/screens/stock_take_detail_screen.dart';
import 'package:stocklite/features/kho/presentation/screens/stock_take_list_screen.dart';

void main() {
  setUp(() => AuthSessionStore.current = _session());
  tearDown(() => AuthSessionStore.current = null);

  group('StockTakeListScreen', () {
    phoneTestWidgets('shows the slips returned by the backend', (tester) async {
      await _pump(tester, StockTakeListScreen(repository: _FakeRepository()));

      expect(find.text('ST-09'), findsOneWidget);
      expect(find.text('Kho A · Cột A-01'), findsOneWidget);
      expect(find.text('Nháp'), findsOneWidget);
    });

    phoneTestWidgets('empty warehouse explains how to start', (tester) async {
      await _pump(
        tester,
        StockTakeListScreen(repository: _FakeRepository(rows: const [])),
      );

      expect(find.text('Chưa có phiếu kiểm kê'), findsOneWidget);
    });

    phoneTestWidgets('a dropped connection offers a retry that reloads',
        (tester) async {
      final repository = _FakeRepository(
        listError: const StockTakeException('Mất mạng', isTransient: true),
      );
      await _pump(tester, StockTakeListScreen(repository: repository));

      expect(find.text('Mất kết nối mạng'), findsOneWidget);
      expect(repository.listCalls, 1);

      repository.listError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(repository.listCalls, 2);
      expect(find.text('ST-09'), findsOneWidget);
    });
  });

  group('StockTakeDetailScreen', () {
    phoneTestWidgets('counts bags, not kilograms', (tester) async {
      await _pump(tester, _detailScreen(_FakeRepository()));

      expect(find.text('Kho A · đã đếm 1/2 bao'), findsOneWidget);
      expect(find.text('Bao #1'), findsOneWidget);
      expect(find.text('Bao #2'), findsOneWidget);
      // Bao chưa tìm thấy phải gọi thẳng tên, không chỉ là một ô chưa tích.
      expect(find.text('Không thấy'), findsOneWidget);
      expect(find.textContaining('Thiếu 1 bao'), findsOneWidget);
    });

    phoneTestWidgets('ticking the missing bag clears the variance warning',
        (tester) async {
      await _pump(tester, _detailScreen(_FakeRepository()));

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Kho A · đã đếm 2/2 bao'), findsOneWidget);
      expect(find.text('Không thấy'), findsNothing);
      expect(find.textContaining('Thiếu 1 bao'), findsNothing);
    });

    phoneTestWidgets('a bag left unweighed keeps its book weight',
        (tester) async {
      await _pump(tester, _detailScreen(_FakeRepository()));

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      // 49,4 (đã cân) + 50 (chưa cân, giữ sổ sách) = 99,4 so với 100 sổ sách.
      expect(find.text('Bao #2'), findsOneWidget);
      expect(find.textContaining('Sổ sách 50 kg · chưa cân'), findsOneWidget);
      expect(find.text('-0,6 kg'), findsOneWidget);
    });

    phoneTestWidgets('saving a draft sends every bag result', (tester) async {
      final repository = _FakeRepository();
      await _pump(tester, _detailScreen(repository));

      await tester.tap(find.text('Lưu nháp'));
      await tester.pumpAndSettle();

      expect(repository.savedLines, hasLength(1));
      final bags = repository.savedLines.single.bags;
      expect(bags.where((b) => b.counted), hasLength(1));
      expect(bags.first.countedWeightKg, 49.4);
      expect(find.text('Đã lưu kết quả kiểm đếm.'), findsOneWidget);
    });

    phoneTestWidgets('a missing bag blocks submit until a reason is given',
        (tester) async {
      final repository = _FakeRepository();
      await _pump(tester, _detailScreen(repository));

      await tester.tap(find.text('Gửi duyệt'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('lệch bao — bắt buộc nhập lý do'),
        findsOneWidget,
      );
      expect(repository.submitCalls, 0);
    });

    phoneTestWidgets('a line nobody counted blocks submit', (tester) async {
      final repository = _FakeRepository(
        detail: _detail(bags: [_bag(1, counted: false), _bag(2, counted: false)]),
      );
      await _pump(tester, _detailScreen(repository));

      await tester.tap(find.text('Gửi duyệt'));
      await tester.pumpAndSettle();

      expect(find.text('Còn 1 dòng chưa kiểm đếm bao nào.'), findsOneWidget);
      expect(repository.submitCalls, 0);
    });

    phoneTestWidgets('a complete count goes through the confirm dialog',
        (tester) async {
      final repository = _FakeRepository(
        detail: _detail(bags: [_bag(1, counted: true), _bag(2, counted: true)]),
      );
      await _pump(tester, _detailScreen(repository));

      await tester.tap(find.text('Gửi duyệt'));
      await tester.pumpAndSettle();

      expect(find.text('Gửi phiếu để duyệt?'), findsOneWidget);
      expect(find.textContaining('Đã đếm 2/2 bao'), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Gửi duyệt'),
      ));
      await tester.pumpAndSettle();

      expect(repository.submitCalls, 1);
      // Phải lưu kết quả trước khi chuyển trạng thái, nếu không số vừa đếm sẽ mất.
      expect(repository.savedLines, isNotEmpty);
    });

    phoneTestWidgets('a submitted slip is read-only', (tester) async {
      final repository = _FakeRepository(
        detail: _detail(
          statusCode: 'SUBMITTED',
          statusName: 'Chờ duyệt',
          bags: [_bag(1, counted: true), _bag(2, counted: true)],
        ),
      );
      await _pump(tester, _detailScreen(repository));

      expect(find.textContaining('số liệu được khoá'), findsOneWidget);
      expect(find.text('Lưu nháp'), findsNothing);
      expect(find.text('Quét QR bao'), findsNothing);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged,
        isNull,
      );
    });

    phoneTestWidgets('a line without bags still accepts a typed weight',
        (tester) async {
      final repository = _FakeRepository(detail: _detail(bags: const []));
      await _pump(tester, _detailScreen(repository));

      expect(find.text('Dòng này không quản lý theo bao'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '87,5');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu nháp'));
      await tester.pumpAndSettle();

      expect(repository.savedLines.single.effectiveActualKg, 87.5);
    });
  });
}

Widget _detailScreen(_FakeRepository repository) =>
    StockTakeDetailScreen(stockTakeId: 5, repository: repository);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void phoneTestWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await callback(tester);
  });
}

StockTakeBag _bag(
  int bagNo, {
  bool counted = false,
  double? countedWeightKg,
}) {
  return StockTakeBag(
    id: bagNo,
    paddyLotBagId: bagNo * 10,
    bagNo: bagNo,
    systemWeightKg: 50,
    counted: counted,
    countedWeightKg: countedWeightKg,
  );
}

StockTakeDetail _detail({
  String statusCode = 'DRAFT',
  String statusName = 'Nháp',
  List<StockTakeBag>? bags,
}) {
  // Mặc định: 2 bao sổ sách, bao #1 đã quét & cân 49,4 kg, bao #2 chưa thấy.
  final lineBags =
      bags ?? [_bag(1, counted: true, countedWeightKg: 49.4), _bag(2)];
  return StockTakeDetail(
    id: 5,
    code: 'ST-09',
    warehouseId: 1,
    warehouseName: 'Kho A',
    statusCode: statusCode,
    statusName: statusName,
    scopeDisplay: 'Cột A-01',
    lines: [
      StockTakeLine(
        id: 90,
        productVariantName: 'Lúa ST25',
        lotCode: 'LOT-A',
        zoneName: 'Khu A',
        locationCode: 'A-01',
        systemQuantity: 100,
        systemBagCount: lineBags.length,
        bags: lineBags,
      ),
    ],
  );
}

class _FakeRepository implements StockTakeRepository {
  _FakeRepository({
    List<StockTakeSummaryRow>? rows,
    StockTakeDetail? detail,
    this.listError,
  })  : rows = rows ??
            const [
              StockTakeSummaryRow(
                id: 5,
                code: 'ST-09',
                warehouseName: 'Kho A',
                statusCode: 'DRAFT',
                statusName: 'Nháp',
                scopeDisplay: 'Cột A-01',
              ),
            ],
        detail = detail ?? _detail();

  final List<StockTakeSummaryRow> rows;
  final StockTakeDetail detail;
  StockTakeException? listError;

  int listCalls = 0;
  int submitCalls = 0;
  List<StockTakeLine> savedLines = const [];

  @override
  Future<List<StockTakeSummaryRow>> getStockTakes() async {
    listCalls += 1;
    final error = listError;
    if (error != null) throw error;
    return rows;
  }

  @override
  Future<StockTakeDetail> getDetail(int id) async => detail;

  @override
  Future<int> create({
    required int warehouseId,
    required StockTakeScope scope,
    String? zoneName,
    int? locationId,
    String? note,
  }) async =>
      5;

  @override
  Future<void> saveCounts(int id, List<StockTakeLine> lines, {String? note}) async {
    savedLines = List.of(lines);
  }

  @override
  Future<void> submit(int id, {String? note}) async {
    submitCalls += 1;
  }

  @override
  Future<ScanBagResult> scanBag(int id, String qrCode) async =>
      const ScanBagResult(matched: false, message: 'Không tìm thấy bao');

  @override
  Future<List<StockTakeLocationOption>> getLocations(int warehouseId) async =>
      const [];

  @override
  Future<List<WarehouseOption>> getWarehouses() async =>
      const [WarehouseOption(id: 1, name: 'Kho A')];
}

AuthSession _session() {
  return const AuthSession(
    accessToken: 'token',
    refreshToken: 'refresh',
    user: AuthUser(id: 1, fullName: 'Tester', email: 'tester@example.com'),
  );
}
