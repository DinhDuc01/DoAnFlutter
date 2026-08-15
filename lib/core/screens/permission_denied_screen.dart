import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

/// Màn hình thông báo khi người dùng không có quyền truy cập tính năng (HTTP 403 Forbidden).
class PermissionDeniedScreen extends StatelessWidget {
  const PermissionDeniedScreen({
    this.menuCode,
    this.message,
    super.key,
  });

  final String? menuCode;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final displayMessage = message ??
        (menuCode != null
            ? 'Tài khoản của bạn chưa được cấp quyền truy cập tính năng "$menuCode".'
            : 'Bạn không có quyền thực hiện thao tác hoặc truy cập trang này.');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Truy cập bị từ chối'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    size: 48,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '403 - Khóa truy cập',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A76F),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
                    }
                  },
                  icon: const Icon(Icons.home_rounded),
                  label: const Text(
                    'Quay lại Trang chủ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
