import 'package:flutter/material.dart';

import '../../../core/app_keys.dart';
import '../../../core/routes/app_routes.dart';

/// Ánh xạ đường dẫn nội bộ kiểu web (directionId do backend gửi) sang route
/// tương ứng trên mobile, và thực hiện điều hướng.
///
/// Backend dùng chung một tập directionId cho cả web lẫn mobile (VD:
/// "/admin/inbound-orders"). Trên mobile chỉ một số màn có sẵn — các thông báo
/// trỏ tới màn không tồn tại sẽ KHÔNG điều hướng (chỉ đổi trạng thái đã đọc).
class NotificationNavigator {
  const NotificationNavigator._();

  /// Bảng ánh xạ directionId (web) -> route mobile.
  static const Map<String, String> _routeByDirection = {
    // Luồng nhập/thu mua -> màn Thu mua.
    '/admin/inbound-orders': AppRoutes.inbound,
    '/admin/rice-purchase': AppRoutes.inbound,
    '/admin/purchase-orders': AppRoutes.inbound,
    // Luồng bán/giao hàng -> màn Giao hàng.
    '/admin/outbound-orders': AppRoutes.outbound,
    '/admin/sales-orders': AppRoutes.outbound,
    // Kiểm kê kho.
    '/admin/stock-takes': AppRoutes.stocktake,
    // Kiểm định & cách ly.
    // Xay xát.
    '/admin/milling-orders': AppRoutes.milling,
  };

  /// Trả về route mobile ứng với [directionId], hoặc null nếu không có màn
  /// tương ứng (khi đó không nên điều hướng).
  static String? routeFor(String? directionId) {
    if (directionId == null) return null;
    var key = directionId.trim().toLowerCase();
    if (key.isEmpty) return null;

    // Bỏ query string / fragment nếu có.
    final queryIndex = key.indexOf('?');
    if (queryIndex >= 0) key = key.substring(0, queryIndex);
    final hashIndex = key.indexOf('#');
    if (hashIndex >= 0) key = key.substring(0, hashIndex);
    // Bỏ dấu "/" ở cuối.
    if (key.length > 1 && key.endsWith('/')) {
      key = key.substring(0, key.length - 1);
    }

    return _routeByDirection[key];
  }

  /// Có màn hình liên quan cho [directionId] hay không.
  static bool hasScreen(String? directionId) => routeFor(directionId) != null;

  /// Điều hướng tới màn liên quan (nếu có). Dùng cho thông báo đẩy FCM khi
  /// người dùng bấm vào (app ở nền hoặc đã tắt). Nếu không có màn cụ thể thì
  /// mở màn danh sách thông báo để người dùng xem chi tiết.
  static void openFromPush(String? directionId) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    final route = routeFor(directionId);
    final currentRoute = ModalRoute.of(navigator.context)?.settings.name;
    final target = route ?? AppRoutes.notifications;
    if (currentRoute == target) return;
    navigator.pushNamed(target);
  }
}
