import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/notifications/data/api_notifications_repository.dart';
import '../../features/notifications/data/notification_center.dart';
import '../../features/notifications/data/notification_navigator.dart';
import '../../firebase_options.dart';
import '../app_keys.dart';

/// Xử lý thông báo đẩy khi app ở nền hoặc đã tắt.
///
/// Hệ điều hành tự hiển thị thông báo (nhờ khối `notification` trong payload),
/// nên hàm này chỉ cần khởi tạo Firebase. Bắt buộc là hàm top-level và có
/// `@pragma('vm:entry-point')` để chạy trong isolate riêng.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

/// Quản lý vòng đời Firebase Cloud Messaging cho ứng dụng: khởi tạo, xin quyền,
/// lấy & đăng ký token, và lắng nghe thông báo realtime.
class FcmService {
  FcmService._();

  /// Thể hiện singleton dùng chung.
  static final FcmService instance = FcmService._();

  final ApiNotificationsRepository _repository = ApiNotificationsRepository();

  bool _appInitialized = false;
  bool _listenersAttached = false;
  String? _currentToken;

  /// Khởi tạo Firebase + đăng ký background handler. Gọi 1 lần trong `main()`
  /// trước khi chạy app.
  Future<void> initApp() async {
    if (_appInitialized) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _appInitialized = true;
    } catch (error) {
      debugPrint('[FCM] Khởi tạo Firebase thất bại: $error');
    }
  }

  /// Bắt đầu nhận thông báo cho người dùng vừa đăng nhập: xin quyền, gắn
  /// listener, lấy & đăng ký token, và tải số chưa đọc ban đầu.
  Future<void> startForUser() async {
    if (!_appInitialized) await initApp();
    if (!_appInitialized) return;

    final messaging = FirebaseMessaging.instance;
    try {
      // Xin quyền hiển thị thông báo trên điện thoại.
      // Android 13+ cần quyền runtime POST_NOTIFICATIONS — dùng permission_handler
      // để chắc chắn hộp thoại hệ thống hiện ra; iOS dùng requestPermission của FCM.
      await ensureNotificationPermission();
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      // iOS: hiện banner/âm thanh cả khi app foreground (Android bỏ qua option này).
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (!_listenersAttached) {
        _listenersAttached = true;
        FirebaseMessaging.onMessage.listen(_onForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
        messaging.onTokenRefresh.listen(_registerToken);
      }

      // Thông báo mở app từ trạng thái đã tắt.
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _onMessageOpened(initialMessage);

      final token = await messaging.getToken();
      if (token != null) await _registerToken(token);
    } catch (error) {
      debugPrint('[FCM] Bắt đầu nhận thông báo thất bại: $error');
    }

    await NotificationCenter.instance.refreshUnread();
  }

  /// Xin quyền thông báo trên điện thoại (hiện hộp thoại hệ thống nếu người
  /// dùng chưa quyết định). Trả về true nếu đã được cấp quyền.
  Future<bool> ensureNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied) return false;
      final result = await Permission.notification.request();
      return result.isGranted;
    } catch (error) {
      debugPrint('[FCM] Xin quyền thông báo thất bại: $error');
      return false;
    }
  }

  /// Dừng nhận thông báo & huỷ token khi đăng xuất.
  Future<void> stopForUser() async {
    try {
      var token = _currentToken;
      if (token == null && _appInitialized) {
        token = await FirebaseMessaging.instance.getToken();
      }
      if (token != null && token.isNotEmpty) {
        await _repository.deleteDeviceToken(token);
      }
    } catch (error) {
      debugPrint('[FCM] Huỷ token thất bại: $error');
    } finally {
      _currentToken = null;
      NotificationCenter.instance.reset();
    }
  }

  Future<void> _registerToken(String token) async {
    _currentToken = token;
    try {
      await _repository.registerDeviceToken(token);
    } catch (error) {
      debugPrint('[FCM] Đăng ký token thất bại: $error');
    }
  }

  /// App đang mở: cập nhật badge + danh sách và hiện SnackBar báo có thông báo.
  void _onForegroundMessage(RemoteMessage message) {
    NotificationCenter.instance.reloadAll();

    final notification = message.notification;
    final title = notification?.title ?? 'Thông báo mới';
    final body = notification?.body ?? '';
    final directionId = message.data['directionId']?.toString();

    final messenger = appMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (body.isNotEmpty)
                Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Xem',
            onPressed: () => NotificationNavigator.openFromPush(directionId),
          ),
        ),
      );
  }

  /// Người dùng bấm vào thông báo đẩy: điều hướng tới màn liên quan (nếu có).
  void _onMessageOpened(RemoteMessage message) {
    NotificationCenter.instance.reloadAll();
    NotificationNavigator.openFromPush(message.data['directionId']?.toString());
  }
}
