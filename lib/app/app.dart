import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/screens/login_screen.dart';

class WmsEcApp extends StatelessWidget {
  const WmsEcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WMS-EC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.login,
      routes: AppRoutes.routes,
      home: const LoginScreen(),
    );
  }
}
