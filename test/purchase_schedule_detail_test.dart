import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_permission.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/thu_mua/data/purchase_schedule_repository.dart';
import 'package:stocklite/features/thu_mua/models/purchase_schedule.dart';
import 'package:stocklite/features/thu_mua/presentation/screens/purchase_schedule_detail_screen.dart';

class _FakePurchaseScheduleRepository extends PurchaseScheduleRepository {
  @override
  Future<PurchaseSchedule> getScheduleDetails(
    PurchaseSchedule schedule,
  ) async {
    return schedule.copyWith(
      farmerPhone: '0912 345 678',
      farmerAddress: 'Ấp 3, Phú Hưng',
    );
  }
}

void main() {
  setUp(() {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: AuthUser(
        id: 1,
        fullName: 'Purchasing',
        email: 'purchase@example.com',
        permissions: [
          UserPermission(
            menuId: 1,
            menuCode: 'RICE_PURCHASE',
            actions: {'READ', 'CREATE'},
          ),
        ],
      ),
    );
  });
  tearDown(() => AuthSessionStore.current = null);

  final schedule = PurchaseSchedule(
    id: 1,
    farmerId: 2,
    code: 'SCH-2026-001',
    farmerName: 'Nguyễn Văn An',
    status: 'Đang đi thu',
    riceVariety: 'IR50404',
    scheduledAt: DateTime(2026, 7, 18),
    estimatedWeightKg: 5000,
    location: 'Ấp 3, Phú Hưng',
    expectedPrice: 6200,
    canCreateReceiptFlag: true,
  );

  testWidgets('purchase schedule detail follows the mobile design',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PurchaseScheduleDetailScreen(
          initialSchedule: schedule,
          repository: _FakePurchaseScheduleRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết lịch thu mua'), findsOneWidget);
    expect(find.textContaining('Nguyễn Văn An'), findsOneWidget);
    expect(find.textContaining('0912 345 678'), findsOneWidget);
    expect(find.textContaining('IR50404 · dự kiến 5t'), findsOneWidget);
    expect(find.textContaining('6.200đ/kg'), findsOneWidget);
    expect(find.text('Tạo phiếu mua từ lịch'), findsOneWidget);
  });

  testWidgets('warehouse user can view schedule detail without mutation CTA',
      (tester) async {
    AuthSessionStore.current = const AuthSession(
      accessToken: 'warehouse-token',
      refreshToken: 'warehouse-refresh',
      user: AuthUser(
        id: 12,
        fullName: 'Warehouse User',
        email: 'warehouse@example.com',
        roles: [
          UserRole(id: 1012, code: 'WAREHOUSE', name: 'Warehouse'),
        ],
        permissions: [
          UserPermission(
            menuId: 1,
            menuCode: 'RICE_PURCHASE',
            actions: {'READ'},
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PurchaseScheduleDetailScreen(
          initialSchedule: schedule,
          repository: _FakePurchaseScheduleRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết lịch thu mua'), findsOneWidget);
    expect(find.textContaining('IR50404'), findsOneWidget);
    expect(find.text('Tạo phiếu mua từ lịch'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
