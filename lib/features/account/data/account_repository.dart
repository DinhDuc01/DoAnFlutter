import '../../auth/data/auth_session_store.dart';
import '../../../core/theme/theme_controller.dart';
import '../models/account_profile.dart';

abstract class AccountRepository {
  Future<AccountProfile> getProfile();
}

class MockAccountRepository implements AccountRepository {
  @override
  Future<AccountProfile> getProfile() async {
    // API_SWAP: Replace mock stats/warehouse with GET /me or GET /account/profile.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final user = AuthSessionStore.current?.user;
    final name = user?.fullName.trim().isNotEmpty == true ? user!.fullName.trim() : 'Người dùng';
    final email = user?.email.trim().isNotEmpty == true ? user!.email.trim() : 'Không có email';
    final avatarInitial = name.substring(0, 1).toUpperCase();

    return AccountProfile(
      name: name,
      email: email,
      role: 'Nhân viên kho',
      avatarInitial: avatarInitial,
      inboundCount: 48,
      outboundCount: 35,
      inventoryCount: 12,
      assignedWarehouse: 'Kho A — TP. Hồ Chí Minh',
      notificationsEnabled: true,
      darkModeEnabled: ThemeController.isDarkMode,
      language: 'Tiếng Việt',
    );
  }
}
