import 'package:flutter/material.dart';

import '../../features/account/presentation/screens/change_password_screen.dart';
import '../../features/account/presentation/screens/personal_info_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/thu_mua/presentation/screens/thu_mua_success_screen.dart';
import '../../features/thu_mua/presentation/screens/purchase_schedule_detail_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/thu_mua/presentation/screens/thu_mua_screen.dart';
import '../../features/thu_mua/models/purchase_schedule.dart';
import '../../features/kho/presentation/screens/stock_take_list_screen.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/scan/presentation/screens/scan_qr_screen.dart';
import '../../features/milling/presentation/screens/milling_preparation_screen.dart';
import '../../features/paddy_lots/presentation/screens/paddy_lot_list_screen.dart';
import '../../features/debts/presentation/screens/debt_screen.dart';
import '../../features/quality_inspection/presentation/screens/quality_inspection_readonly_screen.dart';
import '../../features/sales_orders/presentation/screens/sales_order_list_screen.dart';
import '../../features/outbound_orders/presentation/screens/outbound_order_list_screen.dart';

/// Lớp định nghĩa tất cả các tuyến đường (routes) và điều hướng trong ứng dụng.
class AppRoutes {
  const AppRoutes._(); // Hạn chế khởi tạo đối tượng từ bên ngoài

  // Khai báo tên định danh cho từng màn hình
  static const login = '/login'; // Màn hình Đăng nhập
  static const home = '/home'; // Màn hình Trang chủ
  static const inbound = '/thu-mua'; // Màn hình Nhập kho
  static const purchaseScheduleDetail =
      '/thu-mua/detail'; // Chi tiết lịch thu mua
  static const thuMuaSuccess =
      '/thu-mua/success'; // Màn hình Nhập kho thành công
  static const salesOrders = '/sales-orders'; // Danh sách đơn bán
  static const outboundOrders =
      '/outbound-orders'; // Phiếu xuất kho & giao hàng
  static const stocktake = '/stocktake'; // Kiểm kê kho theo BAO
  static const productDetail = '/products/detail'; // Màn hình Chi tiết sản phẩm
  static const scanQr = '/scan-qr'; // Màn hình Quét mã QR/Barcode
  static const reports = '/reports'; // Màn hình Báo cáo & Biểu đồ
  static const personalInfo = '/personal-info'; // Màn hình Thông tin cá nhân
  static const changePassword = '/change-password'; // Màn hình Đổi mật khẩu
  static const milling = '/xay-xat'; // Luồng hoàn tất xay và cân đóng bao
  static const paddyLots = '/paddy-lots';
  static const debts = '/debts';
  static const qualityInspections = '/quality-inspections';

  /// Map liên kết các tên định danh của route với Widget Builder tương ứng.
  /// Được sử dụng trong MaterialApp ở file app.dart để cấu hình điều hướng.
  static Map<String, WidgetBuilder> get routes {
    return {
      login: (_) => const LoginScreen(),
      home: (context) {
        final initialIndex = ModalRoute.of(context)?.settings.arguments;
        return HomeScreen(
          initialIndex: initialIndex is int ? initialIndex.clamp(0, 5) : 0,
        );
      },
      inbound: (context) {
        final arguments = ModalRoute.of(context)?.settings.arguments;
        return ThuMuaScreen(
          schedule: arguments is PurchaseSchedule ? arguments : null,
        );
      },
      purchaseScheduleDetail: (_) => const PurchaseScheduleDetailScreen(),
      thuMuaSuccess: (_) => const ThuMuaSuccessScreen(),
      // Kiểm kê theo BAO: quét QR từng bao + cân, thay cho cách nhập tay số kg
      // vốn không phản ánh được việc kho gạo lưu hàng theo bao.
      stocktake: (_) => const StockTakeListScreen(),
      productDetail: (_) => const ProductDetailScreen(),
      scanQr: (_) => const ScanQrScreen(),
      reports: (_) => const ReportsScreen(),
      personalInfo: (_) => const PersonalInfoScreen(),
      changePassword: (_) => const ChangePasswordScreen(),
      milling: (_) => const MillingPreparationScreen(),
      paddyLots: (_) => const PaddyLotListScreen(),
      debts: (_) => const DebtScreen(),
      qualityInspections: (_) => const QualityInspectionReadOnlyScreen(),
      salesOrders: (_) => const SalesOrderListScreen(),
      outboundOrders: (_) => const OutboundOrderListScreen(),
    };
  }
}
