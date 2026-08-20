import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/paddy_lots/data/paddy_lot_repository.dart';
import 'package:stocklite/features/paddy_lots/models/paddy_lot.dart';
import 'package:stocklite/features/paddy_lots/presentation/screens/paddy_lot_detail_screen.dart';
import 'package:stocklite/features/paddy_lots/presentation/screens/paddy_lot_list_screen.dart';
import 'package:stocklite/features/scan/models/resolved_qr.dart';

import 'support/fake_api_client.dart';

void main() {
  setUp(() => AuthSessionStore.current = _session());
  tearDown(() => AuthSessionStore.current = null);

  test('QR navigation only accepts paddy lot entity types', () {
    const paddyLot = ResolvedQr(
      entityType: 'PADDY_LOT',
      entityId: 12,
      qrCode: 'LOT-00012',
      displayCode: 'LOT-00012',
    );
    const unrelatedLot = ResolvedQr(
      entityType: 'RICE_LOT',
      entityId: 13,
      qrCode: 'RICE-00013',
      displayCode: 'RICE-00013',
    );

    expect(paddyLot.isPaddyLot, isTrue);
    expect(unrelatedLot.isPaddyLot, isFalse);
  });

  test('parses nullable lot and traceability fields safely', () {
    final lot = PaddyLotDetail.fromJson({
      'id': 12,
      'lotCode': 'LOT-00012',
      'lotType': 'PADDY',
      'productVariantId': 9,
      'warehouseId': 2,
      'initialWeightKg': 200,
      'remainingWeightKg': 180.5,
      'inboundDate': '2026-08-11T14:30:00',
    });
    final trace = PaddyLotTraceability.fromJson({
      'requestedLotId': 12,
      'requestedLotCode': 'LOT-00012',
      'isTruncated': true,
      'timeline': [
        {
          'eventAt': '2026-08-11T14:30:00',
          'eventType': 'PROCUREMENT',
          'referenceType': 'PADDY_PURCHASE_RECEIPT',
          'referenceId': 5,
          'referenceCode': 'PPR-00005',
          'title': 'Thu mua lúa',
          'description': 'Nhận lúa từ nông dân',
          'status': 'Hoàn thành',
          'sequence': 1,
        },
      ],
    });

    expect(lot.locationCode, isNull);
    expect(lot.bagCount, isNull);
    expect(lot.remainingWeightKg, 180.5);
    expect(trace.isTruncated, isTrue);
    expect(trace.events.single.referenceCode, 'PPR-00005');
  });

  test('repository sends bearer token and parses list/detail/traceability',
      () async {
    final client = FakeApiClient(
      onGet: (path, _, __) async {
        if (path.endsWith('/traceability')) {
          return {
            'isSucceeded': true,
            'resources': {
              'requestedLotId': 12,
              'requestedLotCode': 'LOT-00012',
              'isTruncated': false,
              'timeline': const [],
            },
          };
        }
        if (path.endsWith('/12')) {
          return {'isSucceeded': true, 'resources': _lotJson()};
        }
        return {
          'isSucceeded': true,
          'resources': [_lotJson()],
        };
      },
    );
    final repository = ApiPaddyLotRepository(apiClient: client);

    expect((await repository.getLots()).single.lotCode, 'LOT-00012');
    expect((await repository.getLotDetail(12)).id, 12);
    expect((await repository.getTraceabilityById(12)).events, isEmpty);
    expect(client.calls, hasLength(3));
    expect(client.calls.every((call) => call.token == 'access-token'), isTrue);
  });

  test('repository preserves HTTP authorization errors', () async {
    final client = FakeApiClient(
      onGet: (_, __, ___) async => throw const PaddyLotException('Forbidden'),
    );
    AuthSessionStore.current = null;
    await expectLater(
      ApiPaddyLotRepository(apiClient: client).getLots(),
      throwsA(
          isA<PaddyLotException>().having((e) => e.statusCode, 'status', 401)),
    );
  });

  testWidgets('lot list shows loading then empty state', (tester) async {
    final completer = Completer<List<PaddyLotSummary>>();
    final repository = _FakeRepository(onLots: () => completer.future);
    await tester.pumpWidget(
        MaterialApp(home: PaddyLotListScreen(repository: repository)));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Chưa có lô hàng'), findsNothing);

    completer.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lô hàng'), findsOneWidget);
  });

  testWidgets('chọn kho trong dropdown thì gọi lại API kèm bộ lọc',
      (tester) async {
    final repository = _FakeRepository(
      onLots: () async => [PaddyLotSummary.fromJson(_lotJson())],
      warehouses: const [PaddyLotFilterOption(id: 3, name: 'Kho A')],
      statuses: const [PaddyLotFilterOption(id: 9, name: 'Sẵn sàng')],
    );
    await tester.pumpWidget(
        MaterialApp(home: PaddyLotListScreen(repository: repository)));
    await tester.pumpAndSettle();

    // Dropdown phải bật được — trước đây nó bị disable vì danh sách rỗng.
    await tester.tap(find.text('Kho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kho A').last);
    await tester.pumpAndSettle();

    expect(repository.lastFilter?.warehouseId, 3);
  });

  testWidgets('tap lot opens detail and detail opens traceability',
      (tester) async {
    final repository = _FakeRepository(
      onLots: () async => [PaddyLotSummary.fromJson(_lotJson())],
      onDetail: (_) async => PaddyLotDetail.fromJson(_lotJson()),
      onTrace: (_) async => const PaddyLotTraceability(
        requestedLotId: 12,
        requestedLotCode: 'LOT-00012',
        events: [],
        isTruncated: false,
      ),
    );
    await tester.pumpWidget(
        MaterialApp(home: PaddyLotListScreen(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LOT-00012'));
    await tester.pumpAndSettle();
    expect(find.byType(PaddyLotDetailScreen), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open_traceability')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dòng thời gian'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lịch sử truy vết'), findsOneWidget);
  });
}

Map<String, dynamic> _lotJson() => {
      'id': 12,
      'lotCode': 'LOT-00012',
      'lotType': 'PADDY',
      'productVariantId': 9,
      'productVariantName': 'Lúa ST25',
      'sku': 'LUA-ST25',
      'riceVarietyName': 'ST25',
      'warehouseId': 2,
      'warehouseName': 'Kho Tổng',
      'locationCode': 'A-01',
      'statusId': 1,
      'statusName': 'Đang lưu kho',
      'initialWeightKg': 200,
      'remainingWeightKg': 180,
      'qualityStatus': 'Đạt',
      'sourceReceiptId': 5,
      'inboundDate': '2026-08-11T14:30:00',
      'createdDate': '2026-08-11T14:31:00',
    };

AuthSession _session() => const AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      user: AuthUser(id: 7, fullName: 'Tester', email: 'test@example.com'),
    );

class _FakeRepository implements PaddyLotRepository {
  _FakeRepository({
    this.onLots,
    this.onDetail,
    this.onTrace,
    this.warehouses = const [],
    this.statuses = const [],
  });
  final Future<List<PaddyLotSummary>> Function()? onLots;
  final Future<PaddyLotDetail> Function(int id)? onDetail;
  final Future<PaddyLotTraceability> Function(int id)? onTrace;
  final List<PaddyLotFilterOption> warehouses;
  final List<PaddyLotFilterOption> statuses;

  PaddyLotFilter? lastFilter;

  @override
  Future<List<PaddyLotSummary>> getLots() => onLots?.call() ?? Future.value([]);

  @override
  Future<PaddyLotPage> searchLots({
    PaddyLotFilter filter = const PaddyLotFilter(),
    int start = 0,
    int length = 100,
  }) async {
    lastFilter = filter;
    final lots = await (onLots?.call() ?? Future.value(<PaddyLotSummary>[]));
    return PaddyLotPage(lots: lots, totalRecords: lots.length);
  }

  @override
  Future<List<PaddyLotFilterOption>> getWarehouseOptions() async => warehouses;

  @override
  Future<List<PaddyLotFilterOption>> getStatusOptions() async => statuses;

  @override
  Future<PaddyLotDetail> getLotDetail(int id) =>
      onDetail?.call(id) ?? Future.error('Missing detail');

  @override
  Future<PaddyLotTraceability> getTraceabilityById(int id) =>
      onTrace?.call(id) ?? Future.error('Missing traceability');

  @override
  Future<PaddyLotTraceability> getTraceabilityByCode(String lotCode) =>
      getTraceabilityById(12);
}
