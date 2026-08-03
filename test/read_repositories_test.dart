import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/api/api_client.dart';
import 'package:stocklite/core/theme/theme_controller.dart';
import 'package:stocklite/features/account/data/api_account_repository.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/milling/data/api_milling_repository.dart';
import 'package:stocklite/features/milling/models/milling_order.dart';
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
      expect(notifications[0].type, AppNotificationType.alert);
      expect(notifications[0].timeAgo, '10 phút trước');
      expect(notifications[1].type, AppNotificationType.success);
      expect(notifications[1].timeAgo, '2 giờ trước');
      expect(notifications[1].isRead, isTrue);
      expect(notifications[2].type, AppNotificationType.warning);
      expect(notifications[2].timeAgo, '2 ngày trước');
      expect(notifications[3].type, AppNotificationType.info);
      expect(notifications[3].timeAgo, 'Vừa xong');
      expect(notifications[4].timeAgo, 'Không rõ thời gian');
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

    test('returns original schedule when farmer id is invalid', () async {
      final client = FakeApiClient();
      final schedule = _schedule(farmerId: 0);

      final result = await PurchaseScheduleRepository(apiClient: client)
          .getScheduleDetails(schedule);

      expect(result, same(schedule));
      expect(client.calls, isEmpty);
    });

    test('requires login before loading farmer details', () async {
      AuthSessionStore.current = null;

      await expectLater(
        PurchaseScheduleRepository(apiClient: FakeApiClient())
            .getScheduleDetails(_schedule()),
        throwsA(isA<ApiException>()),
      );
    });

    test('enriches schedule from farmer endpoint', () async {
      final client = FakeApiClient(
        onGet: (_, __, ___) async => {
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
      expect(client.calls.single.path, '/api/v1/farmers/2');
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
  );
}
