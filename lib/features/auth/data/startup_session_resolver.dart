import '../models/auth_session.dart';
import 'auth_service.dart';

typedef SessionOperation = Future<void> Function();
typedef SessionSaveOperation = Future<void> Function(AuthSession session);

/// Refreshes a cached session before Home is built.
///
/// Authentication/authorization failures and malformed session responses are
/// fail-closed. A temporary transport failure keeps the cached session so the
/// app can still start offline and retry through the normal API client later.
Future<bool> resolveStartupSession({
  required AuthSession? cachedSession,
  required AuthService authService,
  required SessionSaveOperation saveSession,
  required SessionOperation clearSession,
  required SessionOperation stopNotifications,
  required SessionOperation stopRealtime,
}) async {
  if (cachedSession == null) return false;

  if (cachedSession.user.isMobileBlocked) {
    await _clearSessionAndServices(
      clearSession: clearSession,
      stopNotifications: stopNotifications,
      stopRealtime: stopRealtime,
    );
    return false;
  }

  try {
    final refreshed = await authService.fetchSession(cachedSession);
    if (refreshed.accessToken.isEmpty || refreshed.user.isMobileBlocked) {
      await _clearSessionAndServices(
        clearSession: clearSession,
        stopNotifications: stopNotifications,
        stopRealtime: stopRealtime,
      );
      return false;
    }
    await saveSession(refreshed);
    return true;
  } on AuthException catch (error) {
    final denied = error.statusCode == 401 || error.statusCode == 403;
    if (denied || error.invalidSession) {
      await _clearSessionAndServices(
        clearSession: clearSession,
        stopNotifications: stopNotifications,
        stopRealtime: stopRealtime,
      );
      return false;
    }
    // Transient/unknown transport failures preserve a structurally valid cache.
    return cachedSession.accessToken.isNotEmpty;
  }
}

Future<void> _clearSessionAndServices({
  required SessionOperation clearSession,
  required SessionOperation stopNotifications,
  required SessionOperation stopRealtime,
}) async {
  // Stop user-scoped services before removing the token they may need for
  // unregister/disconnect operations.
  await stopNotifications();
  await stopRealtime();
  await clearSession();
}
