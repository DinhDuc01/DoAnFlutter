import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Lớp cấu hình Theme (giao diện) tổng thể cho ứng dụng bao gồm giao diện sáng (Light) và giao diện tối (Dark).
/// Chứa thiết lập về màu sắc, kiểu dáng của trường nhập liệu (TextField) và các nút bấm (Button).
class AppTheme {
  const AppTheme._(); // Hạn chế khởi tạo đối tượng từ bên ngoài

  /// Định nghĩa giao diện sáng (Light Theme)
  static ThemeData get light {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      scaffoldBackgroundColor: AppColors
          .backgroundStart, // Sử dụng màu xanh gradient làm nền Scaffold
      useMaterial3: true,

      // Thiết lập style chung cho các Input (TextField)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),

      // Thiết lập style chung cho các nút bấm FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48), // Chiều cao tối thiểu 48px
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Định nghĩa giao diện tối (Dark Theme)
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          const Color(0xFF0F172A), // Màu nền tối thẫm cho Dark mode
      cardColor: const Color(0xFF111827),
      dividerColor: const Color(0xFF334155),
      useMaterial3: true,

      // Thiết lập style cho Input trong Dark mode
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),

      // Thiết lập style cho các nút FilledButton trong Dark mode (đồng bộ chiều cao)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
