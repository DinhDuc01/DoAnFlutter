class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
  });

  final int id;
  final String fullName;
  final String email;
  final String? avatarUrl;
}
