import '../../../core/app_keys.dart';
import '../../../core/routes/app_routes.dart';
import '../models/auth_session.dart';
import 'api_auth_service.dart';
import 'auth_service.dart';
import 'auth_session_store.dart';

/// Điều phối việc làm mới (refresh) access token khi API trả về 401.
///
/// Bảo đảm chỉ có DUY NHẤT một request refresh chạy tại một thời điểm
/// (single-flight): nhiều request cùng bị 401 sẽ chờ chung một lần refresh
/// thay vì gọi refresh nhiều lần.
class TokenRefreshCoordinator {
  TokenRefreshCoordinator._();

  static final TokenRefreshCoordinator instance = TokenRefreshCoordinator._();

  final AuthService _authService = ApiAuthService();

  Future<String?>? _inflight;

  /// Được gắn vào [ApiClient.onUnauthorized]. Trả về access token mới nếu làm
  /// mới thành công, hoặc null nếu không thể (khi đó người dùng bị đưa về đăng nhập).
  ///
  /// [expiredToken] là access token đã dùng cho request bị 401 — dùng để bỏ qua
  /// refresh nếu token hiện tại đã được một request khác làm mới trong lúc chờ.
  Future<String?> refreshAccessToken(String? expiredToken) {
    final session = AuthSessionStore.current;
    if (session == null || session.refreshToken.isEmpty) {
      return Future<String?>.value(null);
    }

    // Token đã được làm mới bởi request khác → dùng luôn token hiện tại.
    if (expiredToken != null && session.accessToken != expiredToken) {
      return Future<String?>.value(session.accessToken);
    }

    return _inflight ??= _doRefresh(session).whenComplete(() {
      _inflight = null;
    });
  }

  Future<String?> _doRefresh(AuthSession session) async {
    try {
      final refreshed = await _authService.refresh(session);
      await AuthSessionStore.updateTokens(
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken,
      );
      return refreshed.accessToken;
    } catch (_) {
      // Refresh token cũng hết hạn/không hợp lệ → xoá phiên, đưa về đăng nhập.
      await AuthSessionStore.clear();
      _redirectToLogin();
      return null;
    }
  }

  void _redirectToLogin() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }
}
