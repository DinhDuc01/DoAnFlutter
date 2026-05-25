import '../models/auth_session.dart';

abstract class AuthService {
  Future<AuthSession> login({
    required String email,
    required String password,
  });
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
