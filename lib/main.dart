import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/api/api_client.dart';
import 'core/notifications/fcm_service.dart';
import 'core/realtime/realtime_service.dart';
import 'features/auth/data/auth_session_store.dart';
import 'features/auth/data/token_refresh_coordinator.dart';
import 'features/character/data/character_appearance_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CharacterAppearanceController.instance.load();

  // Gắn hook tự làm mới token khi API trả về 401 (tránh phụ thuộc vòng).
  ApiClient.onUnauthorized =
      TokenRefreshCoordinator.instance.refreshAccessToken;

  // Nạp lại phiên đăng nhập đã lưu để không phải đăng nhập lại mỗi lần mở app.
  await AuthSessionStore.load();
  if (AuthSessionStore.current?.user.isMobileBlocked ?? false) {
    await AuthSessionStore.clear();
  }
  final isLoggedIn = AuthSessionStore.current != null;

  // Khởi tạo Firebase + đăng ký handler thông báo đẩy khi app ở nền/đã tắt.
  await FcmService.instance.initApp();

  // Nếu đã có phiên, bật lại thông báo đẩy + realtime cho người dùng.
  if (isLoggedIn) {
    unawaited(FcmService.instance.startForUser());
    unawaited(RealtimeService.instance.start());
  }

  runApp(StockLiteApp(isLoggedIn: isLoggedIn));
}
