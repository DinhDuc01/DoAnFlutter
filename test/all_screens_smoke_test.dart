import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/reports/presentation/screens/reports_screen.dart';
import 'package:stocklite/features/scan/presentation/screens/scan_qr_screen.dart';
import 'package:stocklite/features/thu_mua/presentation/screens/thu_mua_success_screen.dart';

void main() {
  testWidgets('report screen renders its data cards', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tổng quan hoạt động'), findsOneWidget);
    expect(find.text('Thống kê kho'), findsOneWidget);
  });

  testWidgets('inbound success screen renders fallback result', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ThuMuaSuccessScreen()));

    expect(find.text('Đã tạo phiếu!'), findsOneWidget);
    expect(find.text('1 bao'), findsOneWidget);
  });

  testWidgets('QR scanner screen renders its camera shell', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ScanQrScreen()));
    await tester.pump();

    expect(find.text('Quét mã QR'), findsOneWidget);
  });
}
