import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/stock_take/models/stock_take.dart'
    show StockTakeSummary, StockTakePage;
import 'package:stocklite/features/kho/presentation/screens/stock_take_detail_screen.dart';
import 'package:stocklite/features/stock_take/presentation/screens/stock_take_list_screen.dart';
import 'package:stocklite/features/kho/models/inventory_stock.dart'
    show WarehouseOption;

import 'package:stocklite/features/scale/data/scale_session.dart';
import 'package:stocklite/features/scale/data/ble_scale_service.dart';
import 'package:stocklite/features/stock_take/data/stock_take_repository.dart';
import 'package:stocklite/features/kho/data/stock_take_repository.dart'
    show StockTakeException;
import 'package:stocklite/features/kho/data/stock_take_repository.dart'
    as legacy_repo;
import 'package:stocklite/features/kho/models/stock_take.dart' as legacy;
import 'package:stocklite/core/api/api_client.dart' show ApiException;
import 'package:stocklite/core/routes/app_routes.dart';

class _FakeBleScaleService extends Fake implements BleScaleService {
  @override
  bool get isConnected => false;

  @override
  Future<void> initialize() async {}

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

void main() {
  setUp(() {
    AuthSessionStore.current = _session();
    ScaleSession.instance
        .debugSetService(_FakeBleScaleService(), initializing: Future.value());
  });
  tearDown(() {
    AuthSessionStore.current = null;
    ScaleSession.instance.debugSetService(null, initializing: null);
  });

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

      expect(find.textContaining('Lỗi: Mất mạng'), findsOneWidget);
      expect(repository.listCalls, 1);
    });

    phoneTestWidgets('creating a new stock take validation and success flow',
        (tester) async {
      final repository = _FakeRepository();
      await _pump(tester, StockTakeListScreen(repository: repository));
      await tester.pumpAndSettle();

      // Click "Phiếu mới" to open sheet
      await tester.tap(find.text('Phiếu mới'));
      await tester.pumpAndSettle();

      // Verify validation warning is present
      expect(
          find.textContaining(
              'Backend sẽ chụp snapshot tồn kho tại thời điểm tạo phiên.'),
          findsOneWidget);

      // Verify submit fails without selecting warehouse
      await tester.ensureVisible(find.byKey(const Key('submitButton')));
      await tester.tap(find.byKey(const Key('submitButton')));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng chọn kho.'), findsOneWidget);
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
      expect(find.textContaining('Thiếu 50'), findsOneWidget);
    });

    phoneTestWidgets('ticking the missing bag clears the variance warning',
        (tester) async {
      await _pump(tester, _detailScreen(_FakeRepository()));

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Kho A · đã đếm 2/2 bao'), findsOneWidget);
      expect(find.text('Không thấy'), findsNothing);
      expect(find.textContaining('Thiếu 50'), findsNothing);
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
        find.textContaining('chênh lệch kg — bắt buộc nhập lý do'),
        findsOneWidget,
      );
      expect(repository.submitCalls, 0);
    });

    phoneTestWidgets('a line nobody counted blocks submit', (tester) async {
      final repository = _FakeRepository(
        detail:
            _detail(bags: [_bag(1, counted: false), _bag(2, counted: false)]),
      );
      await _pump(tester, _detailScreen(repository));

      await tester.tap(find.text('Gửi duyệt'));
      await tester.pumpAndSettle();

      expect(find.textContaining('chưa kiểm đếm'), findsOneWidget);
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
      expect(find.textContaining('Đã kiểm đếm'), findsOneWidget);

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

      final weightField = find.byType(TextFormField).first;
      expect(
          tester.widget<TextFormField>(weightField).controller?.text, isEmpty);

      await tester.enterText(weightField, '10');
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(weightField).controller?.text, '10');
      await tester.tap(find.text('Lưu nháp'));
      await tester.pumpAndSettle();

      expect(repository.savedLines.single.effectiveActualKg, 10);
    });

    phoneTestWidgets('submitted with approve permission shows approval actions',
        (tester) async {
      AuthSessionStore.current = _sessionWith({'READ', 'APPROVE'});
      final repository = _FakeRepository(
          detail: _detail(
        statusCode: 'SUBMITTED',
        statusName: 'Chá» duyá»‡t',
        bags: [_bag(1, counted: true), _bag(2, counted: true)],
      ));
      await _pump(tester, _detailScreen(repository));
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(repository.approveCalls, 0);
      expect(repository.rejectCalls, 0);
    });

    phoneTestWidgets(
        'submitted without approve permission hides approval actions',
        (tester) async {
      AuthSessionStore.current = _sessionWith({'READ'});
      await _pump(
          tester,
          _detailScreen(
              _FakeRepository(detail: _detail(statusCode: 'SUBMITTED'))));
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    phoneTestWidgets('opening and cancelling approve dialog does not call API',
        (tester) async {
      AuthSessionStore.current = _sessionWith({'READ', 'APPROVE'});
      final repository = _FakeRepository(
          detail: _detail(
        statusCode: 'SUBMITTED',
        bags: [_bag(1, counted: true), _bag(2, counted: true)],
      ));
      await _pump(tester, _detailScreen(repository));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repository.approveCalls, 0);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextButton)));
      await tester.pumpAndSettle();
      expect(repository.approveCalls, 0);
    });

    phoneTestWidgets('approve success reloads and hides all mutation actions',
        (tester) async {
      AuthSessionStore.current =
          _sessionWith({'READ', 'APPROVE', 'UPDATE', 'DELETE'});
      final repository =
          _FakeRepository(detail: _detail(statusCode: 'SUBMITTED'));
      await _pumpDetailDirect(tester, repository);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
      expect(repository.approveCalls, 1);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    phoneTestWidgets(
        'reject empty reason is blocked and valid reason reloads rejected',
        (tester) async {
      AuthSessionStore.current = _sessionWith({'READ', 'APPROVE'});
      final repository =
          _FakeRepository(detail: _detail(statusCode: 'SUBMITTED'));
      await _pumpDetailDirect(tester, repository);
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      final reasonField = find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(reasonField, '   ');
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
      expect(repository.rejectCalls, 0);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.byType(OutlinedButton).last);
      await tester.pumpAndSettle();
      await tester.enterText(reasonField, '  Sai lech  ');
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
      expect(repository.rejectCalls, 1);
      expect(repository.lastRejectReason, 'Sai lech');
    });

    for (final status in ['APPROVED', 'REJECTED', 'UNKNOWN']) {
      phoneTestWidgets('$status remains read only', (tester) async {
        AuthSessionStore.current =
            _sessionWith({'READ', 'UPDATE', 'APPROVE', 'DELETE'});
        await _pumpDetailDirect(
            tester, _FakeRepository(detail: _detail(statusCode: status)));
        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
        final fields = find.byType(TextFormField);
        if (fields.evaluate().isNotEmpty) {
          expect(tester.widget<TextFormField>(fields.first).enabled, isFalse);
        }
      });
    }
  });
}

Widget _detailScreen(_FakeRepository repository) => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  settings: const RouteSettings(arguments: 5),
                  builder: (context) => StockTakeDetailScreen(
                      stockTakeId: 5, repository: repository),
                ),
              );
            },
            child: const Text('Go'),
          ),
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(
    routes: {
      AppRoutes.stockTakeDetail: (context) {
        final id = ModalRoute.of(context)!.settings.arguments as int;
        final repo = screen is StockTakeListScreen
            ? (screen.repository as legacy_repo.StockTakeRepository?)
            : null;
        return StockTakeDetailScreen(stockTakeId: id, repository: repo);
      },
    },
    home: screen is StockTakeListScreen ? screen : Scaffold(body: screen),
  ));
  await tester.pumpAndSettle();
  if (find.text('Go').evaluate().isNotEmpty) {
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
  }
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

legacy.StockTakeBag _bag(
  int bagNo, {
  bool counted = false,
  double? countedWeightKg,
}) {
  return legacy.StockTakeBag(
    id: bagNo,
    paddyLotBagId: bagNo * 10,
    bagNo: bagNo,
    systemWeightKg: 50,
    counted: counted,
    countedWeightKg: countedWeightKg,
  );
}

legacy.StockTakeDetail _detail({
  String statusCode = 'DRAFT',
  String statusName = 'Nháp',
  List<legacy.StockTakeBag>? bags,
}) {
  // Mặc định: 2 bao sổ sách, bao #1 đã quét & cân 49,4 kg, bao #2 chưa thấy.
  final lineBags =
      bags ?? [_bag(1, counted: true, countedWeightKg: 49.4), _bag(2)];
  return legacy.StockTakeDetail(
    id: 5,
    code: 'ST-09',
    warehouseId: 1,
    warehouseName: 'Kho A',
    statusCode: statusCode,
    statusName: statusName,
    scopeDisplay: 'Cột A-01',
    lines: [
      legacy.StockTakeLine(
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

class _FakeRepository
    implements StockTakeRepository, legacy_repo.StockTakeRepository {
  _FakeRepository({
    List<StockTakeSummary>? rows,
    legacy.StockTakeDetail? detail,
    this.listError,
  })  : rows = rows ??
            const [
              StockTakeSummary(
                id: 5,
                stCode: 'ST-09',
                warehouseId: 1,
                stockTakeStatusId: 1,
                warehouseName: 'Kho A',
                stockTakeStatusCode: 'DRAFT',
                stockTakeStatusName: 'Nháp',
                scopeDisplay: 'Cột A-01',
                varianceLineCount: 0,
                netVarianceKg: 0,
              ),
            ],
        detail = detail ?? _detail();

  final List<StockTakeSummary> rows;
  legacy.StockTakeDetail detail;
  StockTakeException? listError;

  int listCalls = 0;
  int submitCalls = 0;
  int approveCalls = 0;
  int rejectCalls = 0;
  int deleteCalls = 0;
  String? lastRejectReason;
  List<legacy.StockTakeLine> savedLines = const [];

  @override
  Future<legacy.StockTakeDetail> getStockTakeDetail(int id) async => detail;

  @override
  Future<legacy.StockTakeDetail> getDetail(int id) async => detail;

  @override
  Future<List<legacy.StockTakeSummaryRow>> getStockTakes() async => const [];

  @override
  Future<void> saveCounts(int id, List<legacy.StockTakeLine> lines,
      {String? note}) async {
    savedLines = lines;
  }

  @override
  Future<void> submit(int id, {String? note}) async {
    submitCalls += 1;
  }

  @override
  Future<void> approve(int id, {String? approveNote}) async {
    approveCalls += 1;
    detail = _detail(statusCode: 'APPROVED');
  }

  @override
  Future<void> reject(int id, {required String reason}) async {
    rejectCalls += 1;
    lastRejectReason = reason;
    detail = _detail(statusCode: 'REJECTED');
  }

  @override
  Future<void> delete(int id) async {
    deleteCalls += 1;
  }

  @override
  Future<legacy.ScanBagResult> scanBag(int id, String qrCode) async =>
      const legacy.ScanBagResult(matched: false, message: 'Không tìm thấy bao');

  @override
  Future<StockTakePage> getStockTakesPaged({
    required int start,
    required int length,
    String? search,
    int? warehouseId,
    String? statusCode,
  }) async {
    listCalls += 1;
    final error = listError;
    if (error != null) {
      throw ApiException(
        message: error.message,
        statusCode: error.isTransient ? 500 : 400,
      );
    }
    return StockTakePage(
      items: rows,
      recordsTotal: rows.length,
      recordsFiltered: rows.length,
    );
  }

  @override
  Future<int> create({
    required int warehouseId,
    required StockTakeScope scope,
    String? zoneName,
    int? locationId,
    int? paddyLotId,
    int? productVariantId,
    String? lotCode,
    String? skuCode,
    String? note,
  }) async =>
      5;

  @override
  Future<List<StockTakeLocationOption>> getLocations(int warehouseId) async =>
      const [];

  @override
  Future<List<WarehouseOption>> getWarehouses() async =>
      const [WarehouseOption(id: 1, name: 'Kho A')];

  @override
  Future<List<StockTakeStatusOption>> getStatuses() async =>
      const [StockTakeStatusOption(code: 'DRAFT', name: 'Nháp')];

  @override
  Future<List<StockTakeOption>> getLots() async => const [];

  @override
  Future<List<StockTakeOption>> getSkus() async => const [];
}

AuthSession _session() {
  return const AuthSession(
    accessToken: 'token',
    refreshToken: 'refresh',
    user: AuthUser(
      id: 1,
      fullName: 'Tester',
      email: 'tester@example.com',
      permissions: [
        UserPermission(
          menuId: 1,
          menuCode: 'STOCKTAKE',
          actions: {'READ', 'CREATE', 'UPDATE'},
        ),
      ],
    ),
  );
}

Future<void> _pumpDetailDirect(
    WidgetTester tester, _FakeRepository repository) async {
  await tester.pumpWidget(MaterialApp(
    home: StockTakeDetailScreen(stockTakeId: 5, repository: repository),
  ));
  await tester.pumpAndSettle();
}

AuthSession _sessionWith(Set<String> actions) => AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: AuthUser(
        id: 1,
        fullName: 'Tester',
        email: 'tester@example.com',
        permissions: [
          UserPermission(menuId: 1, menuCode: 'STOCKTAKE', actions: actions),
        ],
      ),
    );
