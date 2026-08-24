import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/quality_inspection/data/quality_inspection_repository.dart';
import 'package:stocklite/features/quality_inspection/models/quality_inspection.dart';
import 'package:stocklite/features/quality_inspection/presentation/screens/quality_inspection_detail_screen.dart';
import 'package:stocklite/features/quality_inspection/presentation/screens/quality_inspection_create_screen.dart';
import 'package:stocklite/features/quality_inspection/presentation/screens/quality_inspection_edit_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AuthSessionStore.current = null);

  group('Quality inspection permission and status guard', () {
    testWidgets('selecting a bag hides pass action and keeps quarantine action',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'CREATE'});
      final repository = _FakeQualityCreateRepository();

      await _pumpCreate(tester, repository);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pump();
      await tester.tap(find.textContaining('LOT-PADDY-CREATE').last);
      await tester.pump();

      expect(find.byKey(const Key('quality_create_save_passed')),
          findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();

      expect(find.byKey(const Key('quality_create_save_passed')), findsNothing);
      expect(find.byKey(const Key('quality_create_save_quarantine')),
          findsOneWidget);
      expect(repository.createCalls, 0);
    });

    testWidgets('selected bag can only be submitted as quarantine',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'CREATE'});
      final repository = _FakeQualityCreateRepository();

      await _pumpCreate(tester, repository);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pump();
      await tester.tap(find.textContaining('LOT-PADDY-CREATE').last);
      await tester.pump();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();

      await tester.tap(
          find.byKey(const Key('quality_create_save_quarantine')));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repository.createCalls, 0);

      await tester.tap(find.byType(FilledButton).last);
      await tester.pump();
      expect(repository.createCalls, 1);
      expect(repository.lastCreate?.passedInspection, isFalse);
      expect(repository.lastCreate?.affectedBagIds, [101]);
      expect(repository.lastCreate?.affectedWeightKg, 30);
    });

    testWidgets('READ-only detail hides mutation CTA and does not update',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ'});
      final repository = _FakeQualityRepository(_draft);

      await _pumpDetail(tester, repository);

      expect(find.byKey(const Key('quality_inspection_edit')), findsNothing);
      expect(repository.updateCalls, 0);
    });

    testWidgets('non-PURCHASING cannot create even with CREATE',
        (tester) async {
      AuthSessionStore.current = _session(
        const {'READ', 'CREATE'},
        roleCode: 'WAREHOUSE',
      );
      final repository = _FakeQualityCreateRepository();

      await _pumpCreate(tester, repository);

      expect(find.byKey(const Key('quality_create_save_passed')), findsNothing);
      expect(
        find.byKey(const Key('quality_create_save_quarantine')),
        findsNothing,
      );
      expect(repository.createCalls, 0);
    });

    testWidgets('UPDATE shows edit only for AWAITING_QC draft', (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
      final repository = _FakeQualityRepository(_draft);

      await _pumpDetail(tester, repository);

      expect(find.byKey(const Key('quality_inspection_edit')), findsOneWidget);
      expect(repository.updateCalls, 0);
    });

    testWidgets('non-PURCHASING remains read-only even with UPDATE',
        (tester) async {
      AuthSessionStore.current = _session(
        const {'READ', 'UPDATE'},
        roleCode: 'WAREHOUSE',
      );
      final repository = _FakeQualityRepository(_draft);

      await _pumpDetail(tester, repository);

      expect(find.byKey(const Key('quality_inspection_edit')), findsNothing);
      expect(repository.updateCalls, 0);
    });

    for (final status in <String?>['IN_STOCK', 'QUARANTINE', null, 'UNKNOWN']) {
      testWidgets('status $status is read-only even with UPDATE',
          (tester) async {
        AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
        final repository = _FakeQualityRepository(
          _inspection(lotStatusCode: status),
        );

        await _pumpDetail(tester, repository);

        expect(find.byKey(const Key('quality_inspection_edit')), findsNothing);
        expect(repository.updateCalls, 0);
      });
    }

    testWidgets('direct edit route is blocked without UPDATE', (tester) async {
      AuthSessionStore.current = _session(const {'READ'});
      final repository = _FakeQualityRepository(_draft);

      await tester.pumpWidget(
        MaterialApp(
          home: QualityInspectionEditScreen(
            inspection: _draft,
            lot: _lot,
            repository: repository,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('quality_inspection_save_passed')),
          findsNothing);
      expect(find.byKey(const Key('quality_inspection_save_failed')),
          findsNothing);
      expect(repository.updateCalls, 0);
    });

    testWidgets('direct edit route is blocked for non-draft status',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
      final repository = _FakeQualityRepository(
        _inspection(lotStatusCode: 'QUARANTINE'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QualityInspectionEditScreen(
            inspection: repository.detail,
            lot: _lot,
            repository: repository,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('quality_inspection_save_passed')),
          findsNothing);
      expect(repository.updateCalls, 0);
    });

    testWidgets('cancelling confirmation does not call update', (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
      final repository = _FakeQualityRepository(_draft);
      await _pumpEdit(tester, repository);

      await tester.tap(find.byKey(const Key('quality_inspection_save_passed')));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repository.updateCalls, 0);

      await tester.tap(find.byType(TextButton).last);
      await tester.pump();
      expect(repository.updateCalls, 0);
    });

    testWidgets('confirm calls update once and repeated tap is guarded',
        (tester) async {
      AuthSessionStore.current = _session(const {'READ', 'UPDATE'});
      final repository = _FakeQualityRepository(_draft);
      await _pumpEdit(tester, repository);

      final save = find.byKey(const Key('quality_inspection_save_passed'));
      final onPressed = tester.widget<FilledButton>(save).onPressed!;
      onPressed();
      onPressed();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repository.updateCalls, 0);

      await tester.tap(find.byType(FilledButton).last);
      await tester.pump();
      expect(repository.updateCalls, 1);

      // Dismiss the local post-success navigation prompt.
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();
      expect(repository.updateCalls, 1);
    });
  });
}

Future<void> _pumpCreate(
  WidgetTester tester,
  _FakeQualityCreateRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(home: QualityInspectionCreateScreen(repository: repository)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _pumpDetail(
  WidgetTester tester,
  _FakeQualityRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: QualityInspectionDetailScreen(
        inspectionId: repository.detail.id,
        preview: repository.detail,
        repository: repository,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _pumpEdit(
  WidgetTester tester,
  _FakeQualityRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: QualityInspectionEditScreen(
        inspection: repository.detail,
        lot: _lot,
        repository: repository,
      ),
    ),
  );
  await tester.pump();
}

AuthSession _session(
  Set<String> actions, {
  String roleCode = 'PURCHASING',
}) => AuthSession(
      accessToken: 'quality-token',
      refreshToken: 'quality-refresh',
      user: AuthUser(
        id: 20,
        fullName: 'Quality Tester',
        email: 'quality@test.local',
        roles: [UserRole(id: 4, code: roleCode, name: roleCode)],
        permissions: [
          UserPermission(
            menuId: 50,
            menuCode: 'QUALITY_INSPECTIONS',
            actions: actions,
          ),
        ],
        menus: const [
          UserMenu(id: 50, code: 'QUALITY_INSPECTIONS', name: 'Quality'),
        ],
      ),
    );

const _draft = QualityInspection(
  id: 7,
  paddyLotId: 11,
  lotCode: 'LOT-QC-11',
  lotStatusCode: 'AWAITING_QC',
  passedInspection: false,
);

QualityInspection _inspection({String? lotStatusCode}) => QualityInspection(
      id: 7,
      paddyLotId: 11,
      lotCode: 'LOT-QC-11',
      lotStatusCode: lotStatusCode,
      passedInspection: lotStatusCode == 'IN_STOCK',
    );

const _lot = QualityLot(
  id: 11,
  lotCode: 'LOT-QC-11',
  statusCode: 'AWAITING_QC',
  initialWeightKg: 100,
);

class _FakeQualityRepository implements QualityInspectionRepository {
  _FakeQualityRepository(this.detail);

  final QualityInspection detail;
  int updateCalls = 0;

  @override
  Future<QualityInspection> getDetail(int id) async => detail;

  @override
  Future<List<QualityInspection>> getHistory(int paddyLotId) async => [detail];

  @override
  Future<QualityLot> getLot(int paddyLotId) async => _lot;

  @override
  Future<QualityInspectionPage> loadPage({
    int page = 1,
    int pageSize = 20,
    String search = '',
    bool? passedInspection,
  }) async =>
      QualityInspectionPage(
        items: [detail],
        recordsTotal: 1,
        recordsFiltered: 1,
      );

  @override
  Future<Map<int, QualityLot>> loadLotMap() async => const {11: _lot};

  @override
  Future<Map<int, QualityLot>> loadAwaitingPaddyLots() => loadLotMap();

  @override
  Future<void> update(QualityInspectionUpdate payload) async {
    updateCalls++;
  }
}

class _FakeQualityCreateRepository
    implements QualityInspectionRepository, QualityInspectionCreateRepository {
  int createCalls = 0;
  QualityInspectionCreate? lastCreate;

  @override
  Future<void> create(QualityInspectionCreate payload) async {
    createCalls++;
    lastCreate = payload;
  }

  @override
  Future<Map<int, QualityLot>> loadAwaitingPaddyLots() async => const {
        21: QualityLot(
          id: 21,
          lotCode: 'LOT-PADDY-CREATE',
          lotType: 'PADDY',
          productVariantName: 'Lúa ST25',
          warehouseName: 'Kho chứa 1',
          initialWeightKg: 90,
          bags: [
            QualityLotBag(id: 101, bagNo: 1, weightKg: 30),
            QualityLotBag(id: 102, bagNo: 2, weightKg: 60),
          ],
        ),
      };

  @override
  Future<Map<int, QualityLot>> loadLotMap() => loadAwaitingPaddyLots();

  @override
  Future<QualityInspection> getDetail(int id) =>
      throw UnimplementedError();

  @override
  Future<List<QualityInspection>> getHistory(int paddyLotId) async => const [];

  @override
  Future<QualityLot> getLot(int paddyLotId) async =>
      (await loadAwaitingPaddyLots())[paddyLotId]!;

  @override
  Future<QualityInspectionPage> loadPage({
    int page = 1,
    int pageSize = 20,
    String search = '',
    bool? passedInspection,
  }) async =>
      QualityInspectionPage.empty;

  @override
  Future<void> update(QualityInspectionUpdate payload) =>
      throw UnimplementedError();
}
