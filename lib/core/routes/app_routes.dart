import 'package:flutter/material.dart';

import '../../features/account/presentation/screens/account_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/history/presentation/screens/operation_history_screen.dart';
import '../../features/inbound/presentation/screens/inbound_success_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/inbound/presentation/screens/inbound_screen.dart';
import '../../features/inventory/presentation/screens/inventory_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/outbound/presentation/screens/outbound_success_screen.dart';
import '../../features/outbound/presentation/screens/outbound_screen.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/scan/presentation/screens/scan_qr_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const login = '/login';
  static const home = '/home';
  static const inbound = '/inbound';
  static const inboundSuccess = '/inbound/success';
  static const outbound = '/outbound';
  static const outboundSuccess = '/outbound/success';
  static const inventory = '/inventory';
  static const productDetail = '/products/detail';
  static const scanQr = '/scan-qr';
  static const reports = '/reports';
  static const history = '/history';
  static const notifications = '/notifications';
  static const account = '/account';

  static Map<String, WidgetBuilder> get routes {
    return {
      login: (_) => const LoginScreen(),
      home: (_) => const HomeScreen(),
      inbound: (_) => const InboundScreen(),
      inboundSuccess: (_) => const InboundSuccessScreen(),
      outbound: (_) => const OutboundScreen(),
      outboundSuccess: (_) => const OutboundSuccessScreen(),
      inventory: (_) => const InventoryScreen(),
      productDetail: (_) => const ProductDetailScreen(),
      scanQr: (_) => const ScanQrScreen(),
      reports: (_) => const ReportsScreen(),
      history: (_) => const OperationHistoryScreen(),
      notifications: (_) => const NotificationsScreen(),
      account: (_) => const AccountScreen(),
    };
  }
}
