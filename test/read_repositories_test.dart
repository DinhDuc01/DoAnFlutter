import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/api/api_client.dart';
import 'package:stocklite/core/theme/theme_controller.dart';
import 'package:stocklite/features/account/data/api_account_repository.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/milling/data/api_milling_repository.dart';
import 'package:stocklite/features/milling/models/milling_location.dart';
import 'package:stocklite/features/milling/models/milling_order.dart';
import 'package:stocklite/features/milling/models/milling_output_form.dart';
import 'package:stocklite/features/notifications/data/api_notifications_repository.dart';
import 'package:stocklite/features/notifications/models/app_notification.dart';
import 'package:stocklite/features/quality_inspection/data/quality_inspection_repository.dart';
import 'package:stocklite/features/thu_mua/data/purchase_schedule_repository.dart';
import 'package:stocklite/features/thu_mua/models/purchase_schedule.dart';

import 'support/fake_api_client.dart';

void main() {
  setUp(() {
    AuthSessionStore.current = _session();
    ThemeController.setDarkMode(false);
  });

  tearDown(() {
    AuthSessionStore.current = null;
    ThemeController.setDarkMode(false);
  });

  group('ApiAccountRepository', () {
    test('requires an authenticated session', () async {
      AuthSessionStore.current = null;

      await expectLater(
        ApiAccountRepository(apiClient: FakeApiClient()).getProfile(),
        throwsA(isA<ApiException>()),
      );
    });

    test('combines profile, first role and assigned warehouse', () async {
      ThemeController.setDarkMode(true);
      final client = FakeApiClient(
        onGet: (path, query, token) async {
          if (path == '/api/v1/auth/me') {
            return {
              'resources': {
                'firstName': 'Minh',
                'lastName': 'Khang',
                'email': 'khang@example.com',
                'userRoles': [
                  {'name': 'Warehouse Manager'},
                ],
              },
            };
          }
          return {
            'resources': [
              {'name': 'Kho A', 'address': 'Long An'},
            ],
          };
        },
      );

      final profile =
          await ApiAccountRepository(apiClient: client).getProfile();

      expect(profile.name, 'Minh Khang');
      expect(profile.email, 'khang@example.com');
      expect(profile.role, 'Warehouse Manager');
      expect(profile.avatarInitial, 'M');
      expect(profile.assignedWarehouse, 'Kho A — Long An');
      expect(profile.darkModeEnabled, isTrue);
      expect(client.calls.map((call) => call.token), everyElement('token'));
    });

    test('uses fallback values for empty profile and warehouse responses',
        () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {'resources': <dynamic>[]},
      );

      final profile =
          await ApiAccountRepository(apiClient: client).getProfile();

      expect(profile.name, 'Người dùng');
      expect(profile.email, 'Không có email');
      expect(profile.role, 'Người dùng');
      expect(profile.avatarInitial, 'N');
      expect(profile.assignedWarehouse, 'Chưa phân công kho');
    });
  });

  group('ApiNotificationsRepository', () {
    test('requires an authenticated session', () async {
      AuthSessionStore.current = null;

      await expectLater(
        ApiNotificationsRepository(apiClient: FakeApiClient())
            .getNotifications(),
        throwsA(isA<ApiException>()),
      );
    });

    test('maps notification types, read state and time labels', () async {
      final now = DateTime.now().toUtc();
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'resources': {
            'dataSource': [
              {
                'id': 1,
                'notificationCategoryName': 'Cảnh báo',
                'title': 'Khẩn: tồn kho thấp',
                'content': 'Kiểm tra kho',
                'createdDate':
                    now.subtract(const Duration(minutes: 10)).toIso8601String(),
                'isRead': false,
              },
              {
                'id': 2,
                'title': 'Thành công nhập kho',
                'createdDate':
                    now.subtract(const Duration(hours: 2)).toIso8601String(),
                'isRead': true,
              },
              {
                'id': 3,
                'title': 'Nhắc kiểm kê',
                'createdDate':
                    now.subtract(const Duration(days: 2)).toIso8601String(),
              },
              {
                'id': 4,
                'title': 'Thông tin mới',
                'createdDate':
                    now.add(const Duration(minutes: 5)).toIso8601String(),
              },
              {'id': 5, 'title': 'Không có ngày'},
              'invalid',
            ],
          },
        },
      );

      final notifications = await ApiNotificationsRepository(apiClient: client)
          .getNotifications();

      expect(notifications, hasLength(5));
      expect(notifications.first.id, '4');
      expect(notifications[1].id, '1');
      expect(notifications[1].type, AppNotificationType.alert);
      expect(notifications[1].timeAgo, '10 phút trước');
      final success = notifications.singleWhere((item) => item.id == '2');
      expect(success.type, AppNotificationType.success);
      expect(success.timeAgo, '2 giờ trước');
      expect(success.isRead, isTrue);
      expect(
        notifications.singleWhere((item) => item.id == '3').type,
        AppNotificationType.warning,
      );
      expect(
        notifications.singleWhere((item) => item.id == '3').timeAgo,
        '2 ngày trước',
      );
      expect(
        notifications.singleWhere((item) => item.id == '4').timeAgo,
        'Vừa xong',
      );
      expect(
        notifications.singleWhere((item) => item.id == '5').timeAgo,
        'Không rõ thời gian',
      );
      expect(client.calls.single.body, const {'pageIndex': 1, 'pageSize': 50});
    });

    test('returns empty list when response has no data source', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => const {},
      );

      expect(
        await ApiNotificationsRepository(apiClient: client).getNotifications(),
        isEmpty,
      );
    });

    test('fetch sends page parameters and reads the filtered total', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'resources': {
            'dataSource': [
              {
                'id': 21,
                'title': 'Trang hai',
                'createdDate': '2026-08-13T09:00:00Z',
              },
            ],
            'total': 37,
            'totalFiltered': 23,
          },
        },
      );

      final page = await ApiNotificationsRepository(apiClient: client).fetch(
        pageIndex: 2,
        pageSize: 10,
      );

      expect(page.items.single.id, '21');
      expect(page.total, 23);
      expect(client.calls.single.body, const {
        'pageIndex': 2,
        'pageSize': 10,
      });
    });
  });

  group('PurchaseScheduleRepository', () {
    test('requires login before loading schedules', () async {
      AuthSessionStore.current = null;

      await expectLater(
        PurchaseScheduleRepository(apiClient: FakeApiClient()).getSchedules(),
        throwsA(isA<ApiException>()),
      );
    });

    test('parses and sorts schedules by date', () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {
          'resources': [
            {
              'id': 2,
              'scheduleCode': 'LATE',
              'scheduleDate': '2026-07-24T00:00:00Z',
            },
            'invalid',
            {
              'id': 1,
              'scheduleCode': 'EARLY',
              'scheduleDate': '2026-07-22T00:00:00Z',
            },
          ],
        },
      );

      final schedules =
          await PurchaseScheduleRepository(apiClient: client).getSchedules();

      expect(schedules.map((item) => item.code), ['LATE', 'EARLY']);
      expect(client.calls.single.path, '/api/v1/paddy-purchase-schedules');
    });

    test('parses the paginated schedule response used by the real API',
        () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {
          'isSucceeded': true,
          'resources': {
            'pageIndex': 1,
            'pageSize': 20,
            'dataSource': [
              {
                'id': 9,
                'scheduleCode': 'SCH-009',
                'farmerName': 'Nông hộ An',
                'riceVarietyName': 'ST25',
                'scheduleDate': '2026-07-26T08:00:00Z',
                'estimatedQtyKg': 2500,
                'statusName': 'Đã lên lịch',
              },
            ],
          },
        },
      );

      final schedules =
          await PurchaseScheduleRepository(apiClient: client).getSchedules();

      expect(schedules, hasLength(1));
      expect(schedules.single.code, 'SCH-009');
      expect(schedules.single.farmerName, 'Nông hộ An');
      expect(schedules.single.riceVariety, 'ST25');
      expect(schedules.single.estimatedWeightKg, 2500);
    });

    test('skips farmer lookup when farmer id is invalid', () async {
      final client = FakeApiClient();
      final schedule = _schedule(farmerId: 0);

      final result = await PurchaseScheduleRepository(apiClient: client)
          .getScheduleDetails(schedule);

      // Vẫn làm mới lịch (giống lúa, kho, cờ chặn lập phiếu) nhưng bỏ qua API nông dân.
      expect(result.code, schedule.code);
      expect(result.farmerPhone, isNull);
      expect(client.calls.single.path, '/api/v1/paddy-purchase-schedules/1');
    });

    test('requires login before loading farmer details', () async {
      AuthSessionStore.current = null;

      await expectLater(
        PurchaseScheduleRepository(apiClient: FakeApiClient())
            .getScheduleDetails(_schedule()),
        throwsA(isA<ApiException>()),
      );
    });

    test('enriches schedule from detail + farmer endpoints', () async {
      final client = FakeApiClient(
        onGet: (path, __, ___) async => path.contains('paddy-purchase-schedules')
            ? {
                'resources': {
                  'id': 1,
                  'farmerId': 2,
                  'scheduleCode': 'TM-01',
                  'riceVarietyName': 'ST25',
                  'warehouseName': 'Kho A',
                  'statusCode': 'CONFIRMED',
                  'statusName': 'Đã xác nhận',
                  'estimatedQtyKg': 1000,
                  'receiptCount': 1,
                  'receiptedWeightKg': 1000,
                  'remainingQtyKg': 0,
                  'canCreateReceipt': false,
                },
              }
            : {
                'resources': {
                  'name': 'Nông hộ B',
                  'phone': '0909',
                  'address': 'Tiền Giang',
                },
              },
      );

      final result = await PurchaseScheduleRepository(apiClient: client)
          .getScheduleDetails(_schedule());

      expect(result.farmerName, 'Nông hộ B');
      expect(result.farmerPhone, '0909');
      expect(result.farmerAddress, 'Tiền Giang');
      // Lịch đã đủ khối lượng dự kiến → không cho lập thêm phiếu.
      expect(result.riceVariety, 'ST25');
      expect(result.warehouseName, 'Kho A');
      expect(result.receiptCount, 1);
      expect(result.canCreateReceipt, isFalse);
      expect(result.blockedReason, 'Lịch đã đủ phiếu mua');
      expect(
        client.calls.map((call) => call.path),
        ['/api/v1/paddy-purchase-schedules/1', '/api/v1/farmers/2'],
      );
    });

    test('blocks receipt creation once the estimated weight is reached', () {
      final full = PurchaseSchedule.fromJson({
        'id': 3,
        'statusCode': 'CONFIRMED',
        'estimatedQtyKg': 2000,
        'receiptCount': 2,
        'receiptedWeightKg': 2000,
      });
      final partial = PurchaseSchedule.fromJson({
        'id': 4,
        'statusCode': 'CONFIRMED',
        'estimatedQtyKg': 2000,
        'receiptCount': 1,
        'receiptedWeightKg': 800,
      });
      // Lịch không khai báo khối lượng dự kiến chỉ được lập 1 phiếu.
      final noEstimate = PurchaseSchedule.fromJson({
        'id': 5,
        'statusCode': 'CONFIRMED',
        'receiptCount': 1,
      });

      expect(full.canCreateReceipt, isFalse);
      expect(partial.canCreateReceipt, isTrue);
      expect(noEstimate.canCreateReceipt, isFalse);
    });
  });

  group('ApiQualityInspectionRepository', () {
    test('requires login before loading inspections', () async {
      AuthSessionStore.current = null;

      await expectLater(
        ApiQualityInspectionRepository(apiClient: FakeApiClient())
            .getInspections(),
        throwsA(isA<QualityInspectionException>()),
      );
    });

    test('parses inspections and sorts newest first', () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {
          'resources': [
            {
              'id': 1,
              'paddyLotId': 10,
              'lotCode': 'OLD',
              'inspectedAt': '2026-07-20T00:00:00Z',
              'passedInspection': false,
            },
            {
              'id': 2,
              'paddyLotId': 20,
              'lotCode': 'NEW',
              'inspectedAt': '2026-07-22T00:00:00Z',
              'moisturePercent': '13.5',
              'passedInspection': true,
            },
          ],
        },
      );

      final results = await ApiQualityInspectionRepository(apiClient: client)
          .getInspections();

      expect(results.map((item) => item.lotCode), ['NEW', 'OLD']);
      expect(results.first.moisturePercent, 13.5);
      expect(results.first.passed, isTrue);
    });

    test('loads valid paddy lots and creates fallback codes', () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {
          'resources': [
            {
              'id': 1,
              'lotCode': 'LOT-01',
              'lotType': 'PADDY',
              'remainingWeightKg': 1200,
            },
            {'id': 2},
            {'id': 0, 'lotCode': 'INVALID'},
            {'id': 3, 'lotCode': 'BRAN-01', 'lotType': 'BYPRODUCT'},
          ],
        },
      );

      final lots = await ApiQualityInspectionRepository(apiClient: client)
          .getPaddyLots();

      expect(lots, hasLength(2));
      expect(lots[0].code, 'Lô #2');
      expect(lots[1].code, 'LOT-01');
      expect(lots[1].label, 'LOT-01 · Lúa · 1200 kg');
    });

    test('posts every draft field and returns created id', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'isSucceeded': true,
          'resources': {'id': 99},
        },
      );
      const draft = QualityInspectionDraft(
        paddyLotId: 7,
        passed: true,
        moisturePercent: 13,
        impurityPercent: 2,
        moldLevel: 'Không',
        pestLevel: 'Thấp',
        packagingStatus: 'Tốt',
        handling: 'Nhập kho',
        note: 'Đạt',
      );

      final id = await ApiQualityInspectionRepository(apiClient: client)
          .createInspection(draft);

      expect(id, 99);
      final call = client.calls.single;
      expect(call.path, '/api/v1/quality-inspections');
      expect(call.body?['paddyLotId'], 7);
      expect(call.body?['passedInspection'], isTrue);
      expect(call.body?['moisturePercent'], 13);
      expect(call.body?['note'], 'Đạt');
    });

    test('uses the backend failure message when creation is rejected',
        () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'isSucceeded': false,
          'message': 'Lô đã bị khóa',
        },
      );

      await expectLater(
        ApiQualityInspectionRepository(apiClient: client).createInspection(
          const QualityInspectionDraft(
            paddyLotId: 7,
            passed: false,
            moisturePercent: 15,
            impurityPercent: 3,
          ),
        ),
        throwsA(
          isA<QualityInspectionException>().having(
            (error) => error.message,
            'message',
            'Lô đã bị khóa',
          ),
        ),
      );
    });

    test('validates required quality measurements before posting', () async {
      final client = FakeApiClient();

      await expectLater(
        ApiQualityInspectionRepository(apiClient: client).createInspection(
          const QualityInspectionDraft(paddyLotId: 7, passed: true),
        ),
        throwsA(isA<QualityInspectionException>()),
      );
      expect(client.calls, isEmpty);
    });

    test('rejects an invalid paddy lot before posting', () async {
      final client = FakeApiClient();

      await expectLater(
        ApiQualityInspectionRepository(apiClient: client).createInspection(
          const QualityInspectionDraft(
            paddyLotId: 0,
            passed: false,
            moisturePercent: 13,
            impurityPercent: 2,
          ),
        ),
        throwsA(
          isA<QualityInspectionException>().having(
            (error) => error.message,
            'message',
            contains('không hợp lệ'),
          ),
        ),
      );
      expect(client.calls, isEmpty);
    });

    test('rejects percentage measurements outside zero to one hundred',
        () async {
      final client = FakeApiClient();
      final repository = ApiQualityInspectionRepository(apiClient: client);

      for (final draft in const [
        QualityInspectionDraft(
          paddyLotId: 7,
          passed: false,
          moisturePercent: -0.1,
          impurityPercent: 2,
        ),
        QualityInspectionDraft(
          paddyLotId: 7,
          passed: false,
          moisturePercent: 13,
          impurityPercent: 100.1,
        ),
      ]) {
        await expectLater(
          repository.createInspection(draft),
          throwsA(
            isA<QualityInspectionException>().having(
              (error) => error.message,
              'message',
              contains('0 đến 100%'),
            ),
          ),
        );
      }
      expect(client.calls, isEmpty);
    });

    test('rejects a successful create response without a valid id', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'isSucceeded': true,
          'resources': {'id': 0},
        },
      );

      await expectLater(
        ApiQualityInspectionRepository(apiClient: client).createInspection(
          const QualityInspectionDraft(
            paddyLotId: 7,
            passed: true,
            moisturePercent: 13,
            impurityPercent: 2,
          ),
        ),
        throwsA(
          isA<QualityInspectionException>().having(
            (error) => error.message,
            'message',
            contains('không trả về mã phiếu'),
          ),
        ),
      );
      expect(client.calls, hasLength(1));
    });

    test('loads paginated rice lots and formats their labels', () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {
          'isSucceeded': true,
          'resources': {
            'items': [
              {
                'id': 9,
                'lotCode': 'RICE-09',
                'lotType': 'rice',
                'remainingWeightKg': '125.5',
              },
            ],
          },
        },
      );

      final lots = await ApiQualityInspectionRepository(apiClient: client)
          .getPaddyLots();

      expect(lots.single.id, 9);
      expect(lots.single.lotType, 'rice');
      expect(lots.single.remainingWeightKg, 125.5);
      expect(lots.single.label, 'RICE-09 · Gạo · 126 kg');
    });

    test('converts API errors into quality inspection errors', () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async =>
            throw const ApiException(message: 'Inspection API failed'),
      );

      await expectLater(
        ApiQualityInspectionRepository(apiClient: client).getInspections(),
        throwsA(
          isA<QualityInspectionException>().having(
            (error) => error.message,
            'message',
            'Inspection API failed',
          ),
        ),
      );
    });
  });

  group('ApiMillingRepository', () {
    test('requires login before loading active order', () async {
      AuthSessionStore.current = null;

      await expectLater(
        ApiMillingRepository(apiClient: FakeApiClient()).getActiveOrder(),
        throwsA(isA<MillingApiException>()),
      );
    });

    test('rejects an empty milling order list', () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {'resources': <dynamic>[]},
      );

      await expectLater(
        ApiMillingRepository(apiClient: client).getActiveOrder(),
        throwsA(
          isA<MillingApiException>().having(
            (error) => error.message,
            'message',
            'Chưa có lệnh xay trên server.',
          ),
        ),
      );
    });

    test('loads list then detail without inventing bag records', () async {
      final client = FakeApiClient(
        onGet: (path, query, token) async {
          if (path == '/api/v1/milling-orders') {
            return {
              'resources': [
                {'id': 21},
              ],
            };
          }
          return {
            'resources': {
              'id': 21,
              'millingCode': 'MO-21',
              'computedPaddyKg': 5000,
              'warehouseName': 'Kho A',
              'machineRef': 'SCALE-01',
              'inputs': [
                {'lotCode': 'LOT-01', 'locationId': 12},
              ],
            },
          };
        },
      );

      final order =
          await ApiMillingRepository(apiClient: client).getActiveOrder();

      expect(order.id, 21);
      expect(order.millingCode, 'MO-21');
      expect(order.inputLotCode, 'LOT-01');
      expect(order.inputWeightKg, 5000);
      expect(order.locationCode, '12');
      expect(order.riceBags, isEmpty);
      expect(order.branBags, isEmpty);
      expect(client.calls.map((call) => call.path), [
        '/api/v1/milling-orders',
        '/api/v1/milling-orders/21',
      ]);
    });

    test('loads paged milling orders with search and filters', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'resources': {
            'recordsTotal': 3,
            'recordsFiltered': 1,
            'data': [
              {
                'id': 21,
                'millingCode': 'MO-21',
                'statusId': 3,
                'statusName': 'Đang xay',
                'warehouseId': 7,
                'warehouseName': 'Kho xay',
                'machineRef': 'MILL-01',
                'yieldRateUsed': 0.65,
                'totalRiceOutputKg': 650,
                'computedPaddyKg': 1000,
                'createdDate': '2026-08-01T08:30:00',
              },
            ],
          },
        },
      );

      final page =
          await ApiMillingRepository(apiClient: client).getMillingOrderPage(
        search: 'MO-21',
        statusId: 3,
        warehouseId: 7,
        start: 20,
        length: 20,
      );

      expect(page.recordsTotal, 3);
      expect(page.recordsFiltered, 1);
      expect(page.orders.single.millingCode, 'MO-21');
      expect(page.orders.single.statusCode, 'IN_PROGRESS');
      final call = client.calls.single;
      expect(call.path, '/api/v1/milling-orders/paged-advanced');
      expect(call.body?['start'], 20);
      expect(call.body?['length'], 20);
      expect((call.body?['search'] as Map)['value'], 'MO-21');
      final columns = call.body?['columns'] as List<dynamic>;
      expect(((columns[0] as Map)['search'] as Map)['value'], '3');
      expect(((columns[1] as Map)['search'] as Map)['value'], '7');
    });

    test('loads milling detail with inputs, selected bags and outputs',
        () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {
          'resources': {
            'id': 22,
            'millingCode': 'MO-22',
            'statusId': 5,
            'statusName': 'Hoàn tất',
            'statusCode': 'COMPLETED',
            'warehouseId': 8,
            'warehouseName': 'Kho thành phẩm',
            'riceVarietyName': 'OM5451',
            'yieldRateUsed': 0.7,
            'totalRiceOutputKg': 700,
            'computedPaddyKg': 1000,
            'byproductKg': 120,
            'lossKg': 30,
            'inputs': [
              {
                'id': 1,
                'paddyLotId': 9,
                'lotCode': 'LOT-09',
                'locationId': 4,
                'locationCode': 'A-04',
                'consumedWeightKg': 1000,
                'reservedWeightKg': 1000,
                'bags': [
                  {
                    'bagId': 30,
                    'bagNo': 12,
                    'weightKg': 50,
                    'stackOrder': 1,
                    'status': 'Allocated',
                  },
                ],
              },
            ],
            'outputs': [
              {
                'id': 2,
                'productVariantId': 11,
                'sku': 'RICE-11',
                'outputLotId': 44,
                'outputType': 'RICE',
                'outputWeightKg': 700,
                'bagCount': 28,
                'isByproduct': false,
                'unitCost': 9000,
              },
            ],
          },
        },
      );

      final order = await ApiMillingRepository(apiClient: client)
          .getMillingOrderDetail(22);

      expect(client.calls.single.path, '/api/v1/milling-orders/22');
      expect(order.statusCode, 'COMPLETED');
      expect(order.inputs.single.lotCode, 'LOT-09');
      expect(order.inputs.single.bags.single.weightKg, 50);
      expect(order.outputs.single.sku, 'RICE-11');
      expect(order.riceProductVariantId, 11);
    });

    test('parses nullable milling detail fields safely', () async {
      final order = MillingOrder.fromJson(const {
        'id': 7,
        'millingCode': 'MO-NULL',
        'inputs': [
          {'id': 1, 'paddyLotId': 2, 'consumedWeightKg': null},
        ],
        'outputs': [
          {'id': 3, 'productVariantId': null, 'outputWeightKg': null},
        ],
      });

      expect(order.id, 7);
      expect(order.inputWeightKg, 0);
      expect(order.inputs.single.consumedWeightKg, 0);
      expect(order.outputs.single.outputWeightKg, 0);
      expect(order.outputs.single.isByproduct, isFalse);
    });

    test('completes an order through the correct endpoint', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {'isSucceeded': true},
      );

      await ApiMillingRepository(apiClient: client)
          .completeOrder(_millingOrder());

      expect(client.calls.single.path, '/api/v1/milling-orders/21/complete');
      expect(client.calls.single.token, 'token');
    });

    test('uses backend message when completion fails', () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'isSucceeded': false,
          'message': 'Lệnh đã hoàn tất',
        },
      );

      await expectLater(
        ApiMillingRepository(apiClient: client).completeOrder(_millingOrder()),
        throwsA(
          isA<MillingApiException>().having(
            (error) => error.message,
            'message',
            'Lệnh đã hoàn tất',
          ),
        ),
      );
    });

    test('parses nullable output location fields safely', () {
      final location = MillingLocation.fromJson(const {
        'id': 12,
        'warehouseId': 2,
        'warehouseName': 'Kho A',
        'slotCode': null,
        'zoneName': null,
        'maxCapacity': null,
        'currentOccupancy': null,
        'allowedCategoryId': null,
        'currentProductVariantId': null,
        'isQuarantine': null,
        'isActive': null,
      });

      expect(location.id, 12);
      expect(location.warehouseId, 2);
      expect(location.maxCapacity, isNull);
      expect(location.currentOccupancy, 0);
      expect(location.isQuarantine, isFalse);
      expect(location.isActive, isFalse);
    });

    test('sends putaway suggestion contract without selecting a location',
        () async {
      final client = FakeApiClient(
        onPost: (path, body, token) async {
          expect(path, '/api/v1/putaway/suggestions');
          expect(token, 'token');
          expect(body, {
            'warehouseId': 2,
            'productVariantId': 101,
            'paddyLotId': null,
            'requiredWeightKg': 3250.0,
            'placementMode': 1,
            'top': 5,
          });
          return {
            'isSucceeded': true,
            'resources': {
              'suggestions': [
                {
                  'locationId': 12,
                  'locationCode': 'A01',
                  'zoneName': 'Khu A',
                  'currentOccupancyKg': 100,
                  'maxCapacityKg': 5000,
                  'freeCapacityKg': 4900,
                  'isEmpty': false,
                },
              ],
            },
          };
        },
      );

      final suggestions = await ApiMillingRepository(apiClient: client)
          .getPutawaySuggestions(
            warehouseId: 2,
            productVariantId: 101,
            requiredWeightKg: 3250,
          );

      expect(suggestions.single.locationId, 12);
      expect(client.calls.single.path, '/api/v1/putaway/suggestions');
    });

    test('builds complete outputs from local bags and selected locations',
        () async {
      Map<String, dynamic>? capturedBody;
      final client = FakeApiClient(
        onPost: (path, body, token) async {
          if (path.endsWith('/complete')) capturedBody = body;
          return {'isSucceeded': true};
        },
      );

      const order = MillingOrder(
        id: 21,
        millingCode: 'MO-21',
        inputLotCode: 'LOT-01',
        inputWeightKg: 5000,
        warehouseZone: 'Kho A',
        locationCode: '12',
        scaleCode: 'Cân thủ công',
        statusCode: 'IN_PROGRESS',
        riceProductVariantId: 101,
        branProductVariantId: 102,
        riceBags: [
          MillingBag(index: 1, weightKg: 25),
          MillingBag(index: 2, weightKg: 25),
        ],
        branBags: [MillingBag(index: 1, weightKg: 5)],
      );

      await ApiMillingRepository(apiClient: client).completeOrder(
        order,
        outputLocationIds: const {'RICE': 12, 'BRAN': 13},
      );

      expect(capturedBody?['outputs'], [
        {
          'productVariantId': 101,
          'locationId': 12,
          'outputType': 'RICE',
          'outputWeightKg': 50.0,
          'bagCount': 2,
          'isByproduct': false,
          'unitCost': null,
        },
        {
          'productVariantId': 102,
          'locationId': 13,
          'outputType': 'BRAN',
          'outputWeightKg': 5.0,
          'bagCount': 1,
          'isByproduct': true,
          'unitCost': null,
        },
      ]);
    });

    test('sends validated multi-output form values without UI-only fields',
        () async {
      Map<String, dynamic>? capturedBody;
      String? capturedToken;
      final client = FakeApiClient(
        onPost: (path, body, token) async {
          expect(path, '/api/v1/milling-orders/21/complete');
          capturedBody = body;
          capturedToken = token;
          return {'isSucceeded': true};
        },
      );

      await ApiMillingRepository(apiClient: client).completeOrder(
        _millingOrder(),
        note: 'Đã kiểm tra thủ công',
        outputForms: const [
          MillingOutputFormValue(
            type: MillingOutputType.rice,
            productVariantId: 101,
            locationId: 12,
            bagCount: 4,
            kgPerBag: 25,
            outputWeightKg: 100,
          ),
          MillingOutputFormValue(
            type: MillingOutputType.bran,
            productVariantId: 102,
            locationId: 13,
            bagCount: 1,
            kgPerBag: 5,
            outputWeightKg: 5,
          ),
        ],
      );

      expect(capturedToken, 'token');
      expect(capturedBody, {
        'outputs': [
          {
            'productVariantId': 101,
            'locationId': 12,
            'outputType': 'RICE',
            'outputWeightKg': 100.0,
            'bagCount': 4,
            'isByproduct': false,
            'unitCost': null,
          },
          {
            'productVariantId': 102,
            'locationId': 13,
            'outputType': 'BRAN',
            'outputWeightKg': 5.0,
            'bagCount': 1,
            'isByproduct': true,
            'unitCost': null,
          },
        ],
        'note': 'Đã kiểm tra thủ công',
      });
      expect(capturedBody!.toString(), isNot(contains('kgPerBag')));
      expect(client.calls.where((call) => call.method == 'POST'), hasLength(1));
    });

    test('does not treat an unsuccessful complete response as success',
        () async {
      final client = FakeApiClient(
        onPost: (_, __, ___) async => {
          'isSucceeded': false,
          'message': 'Không thể hoàn tất lệnh',
        },
      );

      await expectLater(
        ApiMillingRepository(apiClient: client).completeOrder(
          _millingOrder(),
          outputForms: const [
            MillingOutputFormValue(
              type: MillingOutputType.rice,
              productVariantId: 101,
              locationId: 12,
              bagCount: 1,
              kgPerBag: 25,
              outputWeightKg: 25,
            ),
          ],
        ),
        throwsA(
          isA<MillingApiException>().having(
            (error) => error.message,
            'message',
            'Không thể hoàn tất lệnh',
          ),
        ),
      );
      expect(client.calls, hasLength(1));
    });

    test('loads physical bags from source suggestions and sends Columns/BagIds',
        () async {
      final client = FakeApiClient(
        onGet: (path, _, __) async {
          if (path == '/api/v1/milling-orders/21/source-suggestions') {
            return {
              'resources': {
                'requiredWeightKg': 100,
                'columns': [
                  {
                    'locationId': 4,
                    'locationCode': 'A-04',
                    'bagIds': [30, 31]
                  },
                ],
                'inputs': [
                  {
                    'locationId': 4,
                    'paddyLotId': 9,
                    'bagIds': [30, 31]
                  },
                ],
              },
            };
          }
          return {
            'resources': {
              'bags': [
                {'id': 30, 'bagNo': 1, 'weightKg': 50, 'status': 'STORED'},
                {'id': 31, 'bagNo': 2, 'weightKg': 50, 'status': 'STORED'},
              ],
            },
          };
        },
        onPost: (path, body, token) async {
          expect(path, '/api/v1/milling-orders/21/reserve');
          expect(body?['columns'], [
            {
              'locationId': 4,
              'bagIds': [30, 31]
            },
          ]);
          expect(token, 'token');
          return {'isSucceeded': true};
        },
      );
      final repository = ApiMillingRepository(apiClient: client);
      final suggestion = await repository.getSourceSuggestion(21);

      expect(suggestion.requiredWeightKg, 100);
      expect(
          suggestion.columns.single.bags.map((bag) => bag.weightKg), [50, 50]);
      expect(suggestion.columns.single.selectedBagIds, [30, 31]);

      await repository.reserveOrder(21, suggestion.columns);
    });

    test('starts a reserved order with a separate request', () async {
      final client = FakeApiClient(
        onPost: (path, body, token) async {
          expect(path, '/api/v1/milling-orders/21/start');
          expect(body, isEmpty);
          expect(token, 'token');
          return {'isSucceeded': true};
        },
      );

      await ApiMillingRepository(apiClient: client).startOrder(21);
    });
  });
}

AuthSession _session() {
  return const AuthSession(
    accessToken: 'token',
    refreshToken: 'refresh',
    user: AuthUser(id: 1, fullName: 'Tester', email: 'tester@example.com'),
  );
}

PurchaseSchedule _schedule({int farmerId = 2}) {
  return PurchaseSchedule(
    id: 1,
    farmerId: farmerId,
    code: 'TM-01',
    farmerName: 'Nông hộ',
    status: 'Đã lên lịch',
    riceVariety: 'IR50404',
    scheduledAt: DateTime(2026, 7, 22),
    estimatedWeightKg: 1000,
    location: 'Long An',
  );
}

MillingOrder _millingOrder() {
  return const MillingOrder(
    id: 21,
    millingCode: 'MO-21',
    inputLotCode: 'LOT-01',
    inputWeightKg: 5000,
    warehouseZone: 'Kho A',
    locationCode: '12',
    scaleCode: 'SCALE-01',
    riceBags: [],
    branBags: [],
    riceProductVariantId: 101,
    branProductVariantId: 102,
  );
}
