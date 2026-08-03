import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/notifications/fcm_service.dart';
import 'features/character/data/character_appearance_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CharacterAppearanceController.instance.load();
  // Khởi tạo Firebase + đăng ký handler thông báo đẩy khi app ở nền/đã tắt.
  await FcmService.instance.initApp();
  runApp(const StockLiteApp());
}
