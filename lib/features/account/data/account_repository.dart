import '../models/account_profile.dart';

abstract class AccountRepository {
  Future<AccountProfile> getProfile();

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmNewPassword,
  });
}
