import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Bắt đầu cân tại nhà'), findsOneWidget);
  });
}
