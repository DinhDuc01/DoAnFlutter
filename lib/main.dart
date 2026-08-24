import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/api/api_client.dart';
import 'core/notifications/fcm_service.dart';
import 'core/realtime/realtime_service.dart';
import 'features/auth/data/auth_session_store.dart';
import 'features/auth/data/api_auth_service.dart';
import 'features/auth/data/token_refresh_coordinator.dart';
import 'features/auth/data/startup_session_resolver.dart';
import 'features/character/data/character_appearance_store.dart';

Future<void> main() async {
  // Mọi plugin dùng channel native (SharedPreferences, Firebase...) chỉ được
  // gọi sau dòng này. Nếu bỏ, app có thể lỗi trước khi widget đầu tiên được dựng.
  WidgetsFlutterBinding.ensureInitialized();
  await CharacterAppearanceController.instance.load();

  // Gắn hook tự làm mới token khi API trả về 401 (tránh phụ thuộc vòng).
  ApiClient.onUnauthorized =
      TokenRefreshCoordinator.instance.refreshAccessToken;

  // Nạp cache trước, sau đó luôn hỏi lại Backend để xác minh phiên. Đây là
  // cơ chế fail-closed: token bị 401/403 hoặc role bị cấm sẽ không vào Home
  // bằng permission cũ lưu trên máy.
  await AuthSessionStore.load();
  final isLoggedIn = await resolveStartupSession(
    cachedSession: AuthSessionStore.current,
    authService: ApiAuthService(),
    saveSession: AuthSessionStore.save,
    clearSession: AuthSessionStore.clear,
    stopNotifications: FcmService.instance.stopForUser,
    stopRealtime: RealtimeService.instance.stop,
  );

  // initApp chỉ cấu hình hạ tầng Firebase. startForUser bên dưới mới đăng ký
  // dịch vụ theo tài khoản, vì vậy không chạy dịch vụ người dùng trước auth.
  await FcmService.instance.initApp();

  // Nếu đã có phiên, bật lại thông báo đẩy + realtime cho người dùng.
  if (isLoggedIn) {
    unawaited(FcmService.instance.startForUser());
    unawaited(RealtimeService.instance.start());
  }

  runApp(StockLiteApp(isLoggedIn: isLoggedIn));
}
