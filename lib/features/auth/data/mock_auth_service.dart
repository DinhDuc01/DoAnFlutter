import 'auth_service.dart';

class MockAuthService implements AuthService {
  @override
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return email.trim().isNotEmpty && password.isNotEmpty;
  }
}
