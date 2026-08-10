import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/notifications/data/notifications_repository.dart';
import 'package:stocklite/features/notifications/models/app_notification.dart';
import 'package:stocklite/features/notifications/presentation/screens/notifications_screen.dart';
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

  group('NotificationsScreen states and actions', () {
    testWidgets('shows loading while notifications are pending',
        (tester) async {
      final completer = Completer<List<AppNotification>>();

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsScreen(
            repository: _NotificationRepository([completer.future]),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when there are no notifications',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsScreen(
            repository: _NotificationRepository([Future.value(const [])]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không có thông báo phù hợp'), findsOneWidget);
    });

    testWidgets('shows error and retries notification loading', (tester) async {
      final firstLoad = Completer<List<AppNotification>>();
      final repository = _NotificationRepository([
        firstLoad.future,
        Future.value([_notification('1', 'Đã tải lại')]),
      ]);
      await tester.pumpWidget(
        MaterialApp(home: NotificationsScreen(repository: repository)),
      );
      firstLoad.completeError('network failed');
      await tester.pumpAndSettle();

      expect(find.text('Không tải được thông báo'), findsOneWidget);
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
        MaterialApp(
          home: NotificationsScreen(
            repository: _NotificationRepository([
              Future.value(notifications),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 thông báo chưa đọc'), findsOneWidget);
      await tester.tap(find.text('Cảnh báo'));
      await tester.pump();
      expect(find.text('Cảnh báo kho'), findsOneWidget);
      expect(find.text('Thông tin'), findsNothing);

      await tester.tap(find.text('Đọc tất cả'));
      await tester.pump();
      expect(find.text('0 thông báo chưa đọc'), findsOneWidget);
    });

    testWidgets('dismisses a notification card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsScreen(
            repository: _NotificationRepository([
              Future.value([_notification('1', 'Có thể đóng')]),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.text('Có thể đóng'), findsNothing);
      expect(find.text('Không có thông báo phù hợp'), findsOneWidget);
    });
  });

  group('QualityInspectionScreen states', () {
    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QualityInspectionScreen(
            repository: _InspectionRepository(inspections: Future.value([])),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có phiếu kiểm chất'), findsOneWidget);
    });

    testWidgets('shows error state', (tester) async {
      final completer = Completer<List<QualityInspection>>();
      await tester.pumpWidget(
        MaterialApp(
          home: QualityInspectionScreen(
            repository: _InspectionRepository(
              inspections: completer.future,
            ),
          ),
        ),
      );
      completer.completeError('inspection failed');
      await tester.pumpAndSettle();

      expect(find.text('Đã xảy ra lỗi'), findsOneWidget);
    });

    testWidgets('renders an inspection result', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QualityInspectionScreen(
            repository: _InspectionRepository(
              inspections: Future.value([
                QualityInspection(
                  id: 1,
                  paddyLotId: 2,
                  lotCode: 'LOT-01',
                  inspectedAt: DateTime(2026, 7, 22),
                  passed: true,
                  moisturePercent: 13.5,
                ),
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LOT-01'), findsOneWidget);
      expect(find.textContaining('Đạt chất lượng'), findsOneWidget);
    });

    testWidgets('create action warns when no paddy lots exist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QualityInspectionScreen(
            repository: _InspectionRepository(
              inspections: Future.value([]),
              lots: Future.value([]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tạo phiếu kiểm chất'));
      await tester.pumpAndSettle();

      expect(
        find.text('Chưa có lô lúa/gạo để kiểm chất.'),
        findsOneWidget,
      );
    });

    testWidgets('quality form rejects empty measurement fields',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QualityInspectionScreen(
            repository: _InspectionRepository(
              inspections: Future.value([]),
              lots: Future.value(
                const [
                  PaddyLotOption(
                    id: 1,
                    code: 'LOT-01',
                    lotType: 'PADDY',
                    remainingWeightKg: 1000,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tạo phiếu kiểm chất'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Lưu kiểm chất'));
      await tester.pump();

      expect(find.text('Vui lòng nhập Độ ẩm (%)'), findsOneWidget);
      expect(find.text('Vui lòng nhập Tạp chất (%)'), findsOneWidget);
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
  _InspectionRepository({
    required this.inspections,
    Future<List<PaddyLotOption>>? lots,
  }) : lots = lots ?? Future.value(const []);

  final Future<List<QualityInspection>> inspections;
  final Future<List<PaddyLotOption>> lots;

  @override
  Future<List<QualityInspection>> getInspections() => inspections;

  @override
  Future<List<PaddyLotOption>> getPaddyLots() => lots;

  @override
  Future<int> createInspection(QualityInspectionDraft draft) async => 1;
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
