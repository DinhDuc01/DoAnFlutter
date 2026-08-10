import 'package:flutter/material.dart';

import '../../../../core/notifications/fcm_service.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../auth/data/auth_session_store.dart';
import '../../../auth/data/api_auth_service.dart';
import '../../data/api_account_repository.dart';
import '../../data/account_repository.dart';
import '../../models/account_profile.dart';
import '../widgets/account_bottom_bar.dart';
import '../widgets/account_header.dart';
import '../widgets/account_menu_section.dart';
import '../widgets/account_stats_card.dart';
import '../widgets/assigned_warehouse_card.dart';

/// Màn hình Quản lý tài khoản (Account Screen / Profile Screen).
/// Hiển thị thông tin người dùng, số liệu thống kê làm việc, thông tin kho hàng phụ trách và các thiết lập cài đặt ứng dụng.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AccountRepository _repository = ApiAccountRepository();

  late final Future<AccountProfile> _profileFuture;
  AccountProfile? _profile;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo Future lấy dữ liệu profile của người dùng
    _profileFuture = _repository.getProfile();
  }

  /// Khởi tạo dữ liệu cục bộ khi tải xong dữ liệu từ Repository (chỉ chạy một lần đầu tiên)
  void _initializeProfile(AccountProfile profile) {
    if (_initialized) return;
    _profile = profile;
    _initialized = true;
  }

  /// Bật/tắt nhận thông báo từ hệ thống
  void _toggleNotifications(bool value) {
    // API_SWAP: Sau này gọi PATCH /account/settings với notificationsEnabled=value.
    final profile = _profile;
    if (profile == null) return;
    setState(() {
      _profile = profile.copyWith(notificationsEnabled: value);
    });
  }

  /// Bật/tắt Dark Mode (Giao diện tối) của hệ thống
  void _toggleDarkMode(bool value) {
    // API_SWAP: Sau này gọi PATCH /account/settings với darkModeEnabled=value hoặc lưu local/SQLite/SharedPref.
    ThemeController.setDarkMode(
        value); // Thay đổi theme trực tiếp thông qua ThemeController
    final profile = _profile;
    if (profile == null) return;
    setState(() {
      _profile = profile.copyWith(darkModeEnabled: value);
    });
  }

  /// Đăng xuất khỏi hệ thống
  Future<void> _logout() async {
    final session = AuthSessionStore.current;
    if (session != null) {
      // Huỷ token FCM trước khi xoá phiên (cần token để gọi API).
      await FcmService.instance.stopForUser();
      // Đóng kết nối realtime dữ liệu.
      await RealtimeService.instance.stop();
      try {
        await ApiAuthService()
            .logout(session)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Local logout must still complete when the server is unavailable.
      }
    }
    AuthSessionStore.current = null;
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FutureBuilder<AccountProfile>(
          future: _profileFuture,
          builder: (context, snapshot) {
            // Hiển thị loading trong lúc đợi dữ liệu được tải về
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            // Xử lý khi xảy ra lỗi tải thông tin tài khoản
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Không tải được tài khoản'));
            }

            _initializeProfile(snapshot.data!);
            final profile = _profile ?? snapshot.data!;

            return SingleChildScrollView(
              child: Column(
                children: [
                  // Phần header thông tin tài khoản
                  AccountHeader(profile: profile),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        // Thẻ hiển thị số lượng phiếu Nhập/Xuất/Kiểm đã thực hiện
                        AccountStatsCard(profile: profile),
                        const SizedBox(height: 10),

                        // Thẻ hiển thị thông tin Kho hàng được chỉ định
                        AssignedWarehouseCard(profile: profile),
                        const SizedBox(height: 10),

                        // Phần menu CÀI ĐẶT
                        AccountMenuSection(
                          title: 'CÀI ĐẶT',
                          items: [
                            AccountMenuItem.toggle(
                              icon: Icons.notifications_none,
                              iconColor: const Color(0xFFFFB020),
                              title: 'Thông báo',
                              subtitle: 'Đang bật',
                              value: profile.notificationsEnabled,
                              onChanged: _toggleNotifications,
                            ),
                            AccountMenuItem.toggle(
                              icon: Icons.dark_mode_outlined,
                              iconColor: const Color(0xFF9CA3AF),
                              title: 'Giao diện tối',
                              subtitle: 'Đang bật',
                              value: profile.darkModeEnabled,
                              onChanged: _toggleDarkMode,
                            ),
                            AccountMenuItem.navigation(
                              icon: Icons.language,
                              iconColor: const Color(0xFF3B82F6),
                              title: 'Ngôn ngữ',
                              subtitle: profile.language,
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Phần menu TÀI KHOẢN & TRỢ GIÚP
                        AccountMenuSection(
                          title: 'TÀI KHOẢN',
                          items: [
                            AccountMenuItem.navigation(
                              icon: Icons.support_agent,
                              iconColor: const Color(0xFF06B6D4),
                              title: 'Trợ giúp & hỗ trợ',
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Phần menu ĐĂNG XUẤT
                        AccountMenuSection(
                          items: [
                            AccountMenuItem.navigation(
                              icon: Icons.logout,
                              iconColor: const Color(0xFFFB2C36),
                              title: 'Đăng xuất',
                              onTap: _logout,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar:
          const AccountBottomBar(), // Thanh Bottom Nav của trang Profile
    );
  }
}
