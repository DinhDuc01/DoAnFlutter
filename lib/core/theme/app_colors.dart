import 'package:flutter/material.dart';

/// Lớp định nghĩa bảng màu (color palette) của ứng dụng.
/// Cung cấp các hằng số màu sắc và các phương thức tiện ích để tự động thay đổi màu dựa vào chế độ Sáng/Tối.
class AppColors {
  const AppColors._(); // Hạn chế khởi tạo đối tượng từ bên ngoài

  // Các màu sắc cơ bản (Theme sáng)
  static const primary =
      Color(0xFF16B957); // Màu chủ đạo (Xanh lá cây thương hiệu)
  static const primaryDark = Color(0xFF0F8F43); // Màu chủ đạo đậm hơn
  static const backgroundStart =
      Color(0xFFF0FDF4); // Màu gradient bắt đầu của nền
  static const backgroundEnd =
      Color(0xFFDCFFE7); // Màu gradient kết thúc của nền
  static const surface =
      Color(0xFFFFFFFF); // Màu nền của các thẻ (Card/Surface)
  static const textPrimary = Color(0xFF111827); // Màu chữ chính (Đen/Xám đậm)
  static const textSecondary = Color(0xFF6B7280); // Màu chữ phụ (Xám nhạt)
  static const border = Color(0xFFE5E7EB); // Màu đường viền

  /// Kiểm tra xem ứng dụng hiện đang ở chế độ giao diện tối (Dark Mode) hay không.
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Lấy màu nền (scaffold background) phù hợp với chế độ giao diện hiện tại.
  static Color backgroundFor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  /// Lấy màu của bề mặt (Surface Color) như Card/Dialog theo chế độ giao diện hiện tại.
  static Color surfaceFor(BuildContext context) {
    return isDark(context) ? const Color(0xFF111827) : surface;
  }

  /// Lấy màu của bề mặt tinh giản (Subtle Surface) phù hợp với chế độ sáng/tối.
  static Color subtleSurfaceFor(BuildContext context) {
    return isDark(context) ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
  }

  /// Lấy màu chữ chính phù hợp với chế độ sáng/tối.
  static Color textPrimaryFor(BuildContext context) {
    return isDark(context) ? const Color(0xFFF9FAFB) : textPrimary;
  }

  /// Lấy màu chữ phụ phù hợp với chế độ sáng/tối.
  static Color textSecondaryFor(BuildContext context) {
    return isDark(context) ? const Color(0xFFCBD5E1) : textSecondary;
  }

  /// Lấy màu đường viền (border color) phù hợp với chế độ sáng/tối.
  static Color borderFor(BuildContext context) {
    return isDark(context) ? const Color(0xFF334155) : border;
  }
}
