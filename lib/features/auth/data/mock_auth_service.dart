import '../models/auth_session.dart';
import 'auth_service.dart';

class MockAuthService implements AuthService {
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (email.trim().isEmpty || password.isEmpty) {
      throw const AuthException('Vui lòng nhập tài khoản và mật khẩu');
    }

    return AuthSession(
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
      user: AuthUser(
        id: 1,
        fullName: 'Nguyễn Văn A',
        email: email,
      ),
    );
  }
}
