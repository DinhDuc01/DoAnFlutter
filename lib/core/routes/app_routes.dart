import 'package:flutter/material.dart';

import '../../features/account/presentation/screens/account_screen.dart';
import '../../features/account/presentation/screens/change_password_screen.dart';
import '../../features/account/presentation/screens/personal_info_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/thu_mua/presentation/screens/thu_mua_success_screen.dart';
import '../../features/thu_mua/presentation/screens/purchase_schedule_detail_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/thu_mua/presentation/screens/thu_mua_screen.dart';
import '../../features/thu_mua/models/purchase_schedule.dart';
import '../../features/kho/presentation/screens/kho_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/giao_hang/presentation/screens/giao_hang_success_screen.dart';
import '../../features/giao_hang/presentation/screens/giao_hang_screen.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/scan/presentation/screens/scan_qr_screen.dart';
import '../../features/milling/presentation/screens/milling_preparation_screen.dart';
import '../../features/scale/presentation/screens/inventory_weighing_screen.dart';
import '../../features/paddy_lots/presentation/screens/paddy_lot_list_screen.dart';

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
  static const outbound = '/giao-hang'; // Màn hình Xuất kho
  static const giaoHangSuccess =
      '/giao-hang/success'; // Màn hình Xuất kho thành công
  static const stocktake = '/stocktake';
  @Deprecated('Use stocktake')
  static const inventory = stocktake;
  static const productDetail = '/products/detail'; // Màn hình Chi tiết sản phẩm
  static const scanQr = '/scan-qr'; // Màn hình Quét mã QR/Barcode
  static const reports = '/reports'; // Màn hình Báo cáo & Biểu đồ
  static const notifications = '/notifications'; // Màn hình Thông báo
  static const account = '/account'; // Màn hình Tài khoản & Hồ sơ cá nhân
  static const personalInfo = '/personal-info'; // Màn hình Thông tin cá nhân
  static const changePassword = '/change-password'; // Màn hình Đổi mật khẩu
  static const milling = '/xay-xat'; // Luồng hoàn tất xay và cân đóng bao
  static const scale = '/scale'; // Cân sản phẩm trong kho
  static const paddyLots = '/paddy-lots';

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
      outbound: (_) => const GiaoHangScreen(),
      giaoHangSuccess: (_) => const GiaoHangSuccessScreen(),
      stocktake: (_) => const KhoScreen(),
      productDetail: (_) => const ProductDetailScreen(),
      scanQr: (_) => const ScanQrScreen(),
      reports: (_) => const ReportsScreen(),
      notifications: (_) => const NotificationsScreen(),
      account: (_) => const AccountScreen(),
      personalInfo: (_) => const PersonalInfoScreen(),
      changePassword: (_) => const ChangePasswordScreen(),
      milling: (_) => const MillingPreparationScreen(),
      scale: (_) => const InventoryWeighingScreen(),
      paddyLots: (_) => const PaddyLotListScreen(),
    };
  }
}
