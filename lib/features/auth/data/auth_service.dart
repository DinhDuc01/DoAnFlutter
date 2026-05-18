abstract class AuthService {
  Future<bool> login({
    required String email,
    required String password,
  });
}
