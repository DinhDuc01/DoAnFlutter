import 'package:flutter/material.dart';

import '../core/app_keys.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';

class StockLiteApp extends StatelessWidget {
  const StockLiteApp({this.isLoggedIn = false, super.key});

  /// Đã có phiên đăng nhập khôi phục được → vào thẳng trang chủ, khỏi đăng nhập lại.
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Lúa gạo Tuấn Mây',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: appMessengerKey,
          initialRoute: isLoggedIn ? AppRoutes.home : AppRoutes.login,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
