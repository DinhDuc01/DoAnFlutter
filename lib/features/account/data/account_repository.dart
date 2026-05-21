import '../models/account_profile.dart';

abstract class AccountRepository {
  Future<AccountProfile> getProfile();
}

class MockAccountRepository implements AccountRepository {
  @override
  Future<AccountProfile> getProfile() async {
    // API_SWAP: Replace this mock response with GET /me or GET /account/profile.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return const AccountProfile(
      name: 'Nguyễn Văn A',
      email: 'nhanvien@stocklite.vn',
      role: 'Nhân viên kho',
      avatarInitial: 'N',
      inboundCount: 48,
      outboundCount: 35,
      inventoryCount: 12,
      assignedWarehouse: 'Kho A — TP. Hồ Chí Minh',
      notificationsEnabled: true,
      darkModeEnabled: true,
      language: 'Tiếng Việt',
    );
  }
}
