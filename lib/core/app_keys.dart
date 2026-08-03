import 'package:flutter/material.dart';

/// Khoá điều hướng toàn cục — cho phép điều hướng từ ngoài cây widget
/// (VD: khi người dùng bấm vào thông báo đẩy FCM lúc app ở nền/đã tắt).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Khoá ScaffoldMessenger toàn cục — hiển thị SnackBar thông báo realtime
/// khi app đang mở (foreground) từ bất kỳ đâu.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
