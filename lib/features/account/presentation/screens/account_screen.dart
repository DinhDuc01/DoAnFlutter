import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../data/account_repository.dart';
import '../../models/account_profile.dart';
import '../widgets/account_bottom_bar.dart';
import '../widgets/account_header.dart';
import '../widgets/account_menu_section.dart';
import '../widgets/account_stats_card.dart';
import '../widgets/assigned_warehouse_card.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AccountRepository _repository = MockAccountRepository();

  late final Future<AccountProfile> _profileFuture;
  AccountProfile? _profile;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // API_SWAP: This is where the screen requests account profile data.
    _profileFuture = _repository.getProfile();
  }

  void _initializeProfile(AccountProfile profile) {
    if (_initialized) return;
    _profile = profile;
    _initialized = true;
  }

  void _toggleNotifications(bool value) {
    // API_SWAP: Call PATCH /account/settings notificationsEnabled=value.
    final profile = _profile;
    if (profile == null) return;
    setState(() {
      _profile = profile.copyWith(notificationsEnabled: value);
    });
  }

  void _toggleDarkMode(bool value) {
    // API_SWAP: Call PATCH /account/settings darkModeEnabled=value or save locally.
    ThemeController.setDarkMode(value);
    final profile = _profile;
    if (profile == null) return;
    setState(() {
      _profile = profile.copyWith(darkModeEnabled: value);
    });
  }

  void _logout() {
    // API_SWAP: Call POST /auth/logout and clear token storage.
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
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Không tải được tài khoản'));
            }

            _initializeProfile(snapshot.data!);
            final profile = _profile ?? snapshot.data!;

            return SingleChildScrollView(
              child: Column(
                children: [
                  AccountHeader(profile: profile),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        AccountStatsCard(profile: profile),
                        const SizedBox(height: 10),
                        AssignedWarehouseCard(profile: profile),
                        const SizedBox(height: 10),
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
                        AccountMenuSection(
                          title: 'TÀI KHOẢN',
                          items: [
                            AccountMenuItem.navigation(
                              icon: Icons.lock_outline,
                              iconColor: const Color(0xFF8B5CF6),
                              title: 'Đổi mật khẩu',
                              onTap: () {},
                            ),
                            AccountMenuItem.navigation(
                              icon: Icons.support_agent,
                              iconColor: const Color(0xFF06B6D4),
                              title: 'Trợ giúp & hỗ trợ',
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
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
      bottomNavigationBar: const AccountBottomBar(),
    );
  }
}
