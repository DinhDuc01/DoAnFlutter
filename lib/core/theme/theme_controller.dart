import 'package:flutter/material.dart';

/// Bộ điều khiển giao diện (Theme Controller) quản lý trạng thái chuyển đổi giữa chế độ Sáng (Light) và Tối (Dark).
/// Sử dụng ValueNotifier để thông báo cho toàn bộ ứng dụng biết khi chế độ giao diện thay đổi.
class ThemeController {
  ThemeController._(); // Hạn chế khởi tạo trực tiếp từ bên ngoài

  /// ValueNotifier lưu trữ ThemeMode hiện tại (mặc định là ThemeMode.light).
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  /// Getter trả về true nếu chế độ hiện tại là tối (Dark Mode).
  static bool get isDarkMode => mode.value == ThemeMode.dark;

  /// Phương thức bật/tắt chế độ tối.
  /// [enabled] truyền vào true để kích hoạt Dark Mode, truyền false để về Light Mode.
  static void setDarkMode(bool enabled) {
    mode.value = enabled ? ThemeMode.dark : ThemeMode.light;
  }
}
