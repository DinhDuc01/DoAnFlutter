import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/widgets/state_widgets.dart';
import 'package:stocklite/features/notifications/data/notifications_repository.dart';
import 'package:stocklite/features/notifications/models/app_notification.dart';
import 'package:stocklite/features/notifications/presentation/widgets/notifications_tab.dart';
import 'package:stocklite/features/quality_inspection/data/quality_inspection_repository.dart';
import 'package:stocklite/features/quality_inspection/models/quality_inspection.dart';
import 'package:stocklite/features/quality_inspection/presentation/screens/quality_inspection_screen.dart';
import 'package:stocklite/features/reports/data/warehouse_report_repository.dart';
import 'package:stocklite/features/reports/models/warehouse_report.dart';
import 'package:stocklite/features/reports/presentation/screens/reports_screen.dart';

void main() {
  group('ReportsScreen states', () {
    testWidgets('shows loading while report is pending', (tester) async {
      final completer = Completer<WarehouseReport>();

      await tester.pumpWidget(
        MaterialApp(
          home: ReportsScreen(repository: _ReportRepository(completer.future)),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error when report loading fails', (tester) async {
      final completer = Completer<WarehouseReport>();
      await tester.pumpWidget(
        MaterialApp(
          home: ReportsScreen(
            repository: _ReportRepository(completer.future),
          ),
        ),
      );
      completer.completeError('report failed');
      await tester.pumpAndSettle();

      expect(find.text('Không tải được thống kê kho'), findsOneWidget);
    });

    testWidgets('renders report summary and product data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReportsScreen(
            repository: _ReportRepository(Future.value(_report())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kho Test — Tháng 7/2026'), findsOneWidget);
      expect(find.text('Gạo thơm'), findsOneWidget);
      expect(find.text('1.2k'), findsOneWidget);
    });
  });

  group('NotificationsTab states and actions', () {
    // Màn NotificationsScreen đứng riêng đã bị xoá vì trùng với tab này; toàn
    // bộ hành vi (lọc, đọc tất cả, xoá) nay nằm ở NotificationsTab.
    Widget host(NotificationsRepository repository) => MaterialApp(
          home: Scaffold(body: NotificationsTab(repository: repository)),
        );

    testWidgets('shows loading while notifications are pending',
        (tester) async {
      final completer = Completer<List<AppNotification>>();

      await tester.pumpWidget(
        host(_NotificationRepository([completer.future])),
      );
      await tester.pump();

      expect(find.byType(ListSkeleton), findsOneWidget);
    });

    testWidgets('shows empty state when there are no notifications',
        (tester) async {
      await tester.pumpWidget(
        host(_NotificationRepository([Future.value(const [])])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không có thông báo mới'), findsOneWidget);
    });

    testWidgets('shows error and retries notification loading', (tester) async {
      final firstLoad = Completer<List<AppNotification>>();
      final repository = _NotificationRepository([
        firstLoad.future,
        Future.value([_notification('1', 'Đã tải lại')]),
      ]);
      await tester.pumpWidget(host(repository));
      firstLoad.completeError('network failed');
      await tester.pumpAndSettle();

      // HErrorState thay message chi tiết bằng nhãn chung.
      expect(find.text('Đã xảy ra lỗi'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Đã tải lại'), findsOneWidget);
      expect(repository.callCount, 2);
    });

    testWidgets('filters alerts and marks all notifications as read',
        (tester) async {
      final notifications = [
        _notification('1', 'Cảnh báo kho', type: AppNotificationType.alert),
        _notification('2', 'Thông tin', type: AppNotificationType.info),
        _notification('3', 'Đã đọc', isRead: true),
      ];
      await tester.pumpWidget(
        host(_NotificationRepository([Future.value(notifications)])),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 thông báo chưa đọc'), findsOneWidget);
      await tester.tap(find.text('Cảnh báo'));
      await tester.pump();
      expect(find.text('Cảnh báo kho'), findsOneWidget);
      expect(find.text('Thông tin'), findsNothing);

      await tester.tap(find.text('Đọc tất cả'));
      await tester.pump();
      expect(find.text('Đã đọc hết thông báo'), findsOneWidget);
    });

    testWidgets('dismisses a notification card', (tester) async {
      await tester.pumpWidget(
        host(_NotificationRepository([
          Future.value([_notification('1', 'Có thể đóng')]),
        ])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.text('Có thể đóng'), findsNothing);
      expect(find.text('Không có thông báo mới'), findsOneWidget);
    });

    testWidgets('tap only shows notification detail and does not navigate',
        (tester) async {
      const notification = AppNotification(
        id: '9',
        type: AppNotificationType.info,
        title: 'Chi tiết thông báo',
        message: 'Nội dung cần xem',
        timeAgo: 'Vừa xong',
        isRead: false,
        directionId: '/admin/milling-orders',
      );
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/admin/milling-orders': (_) => const Text('Màn nghiệp vụ'),
          },
          home: NotificationsTab(
            repository: _NotificationRepository([
              Future.value(const [notification]),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chi tiết thông báo'));
      await tester.pumpAndSettle();

      expect(find.text('Nội dung cần xem'), findsWidgets);
      expect(find.text('Đóng'), findsOneWidget);
      expect(find.text('Màn nghiệp vụ'), findsNothing);
    });
  });

  group('QualityInspectionScreen states', () {
    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QualityInspectionScreen(repository: _InspectionRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có phiếu kiểm định'), findsOneWidget);
    });

    testWidgets('shows error state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QualityInspectionScreen(
            repository: _InspectionRepository(failing: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đã xảy ra lỗi'), findsOneWidget);
    });

    testWidgets('renders an inspection row without create action',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QualityInspectionScreen(
            repository: _InspectionRepository(
              items: [
                QualityInspection(
                  id: 1,
                  paddyLotId: 2,
                  lotCode: 'LOT-01',
                  lotStatusCode: 'IN_STOCK',
                  inspectedAt: DateTime(2026, 7, 22),
                  passedInspection: true,
                  moisturePercent: 13.5,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LOT-01'), findsOneWidget);
      expect(find.text('Đạt'), findsOneWidget);
      // Mobile không được tạo phiếu kiểm định — chỉ web mới có luồng này.
      expect(find.textContaining('Tạo phiếu'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });
}

class _ReportRepository implements WarehouseReportRepository {
  _ReportRepository(this.result);
  final Future<WarehouseReport> result;
  @override
  Future<WarehouseReport> getWarehouseReport() => result;
}

class _NotificationRepository implements NotificationsRepository {
  _NotificationRepository(this.results);
  final List<Future<List<AppNotification>>> results;
  int callCount = 0;

  @override
  Future<List<AppNotification>> getNotifications() {
    final index = callCount < results.length ? callCount : results.length - 1;
    callCount++;
    return results[index];
  }
}

class _InspectionRepository implements QualityInspectionRepository {
  _InspectionRepository(
      {this.items = const <QualityInspection>[], this.failing = false});

  final List<QualityInspection> items;
  final bool failing;

  @override
  Future<QualityInspectionPage> loadPage({
    int page = 1,
    int pageSize = 20,
    String search = '',
    bool? passedInspection,
  }) async {
    if (failing) throw const QualityInspectionException('inspection failed');
    return QualityInspectionPage(
      items: items,
      recordsTotal: items.length,
      recordsFiltered: items.length,
    );
  }

  @override
  Future<QualityInspection> getDetail(int id) async => items.first;

  @override
  Future<List<QualityInspection>> getHistory(int paddyLotId) async => items;

  @override
  Future<QualityLot> getLot(int paddyLotId) async =>
      const QualityLot(id: 1, lotCode: 'LOT-01');

  @override
  Future<Map<int, QualityLot>> loadLotMap() async => const <int, QualityLot>{};

  @override
  Future<Map<int, QualityLot>> loadAwaitingPaddyLots() => loadLotMap();

  @override
  Future<void> update(QualityInspectionUpdate payload) async =>
      throw StateError('Test không được phép ghi dữ liệu.');
}

WarehouseReport _report() {
  return const WarehouseReport(
    warehouseName: 'Kho Test',
    periodLabel: 'Tháng 7/2026',
    totalThuMua: 10,
    totalGiaoHang: 5,
    totalStockLabel: '1.2k',
    weeklyActivities: [
      WeeklyWarehouseActivity(dayLabel: 'T2', inbound: 10, outbound: 5),
    ],
    topThuMuaProducts: [
      TopThuMuaProduct(
        name: 'Gạo thơm',
        quantity: 10,
        color: Colors.green,
      ),
    ],
  );
}

AppNotification _notification(
  String id,
  String title, {
  AppNotificationType type = AppNotificationType.info,
  bool isRead = false,
}) {
  return AppNotification(
    id: id,
    type: type,
    title: title,
    message: 'Nội dung',
    timeAgo: 'Vừa xong',
    isRead: isRead,
  );
}
