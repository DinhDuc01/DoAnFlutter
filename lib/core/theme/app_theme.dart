import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme tổng của ứng dụng (Light + Dark).
///
/// Đợt này được làm giàu để nâng đồng loạt mọi màn hình: thang typography rõ
/// ràng, input/nút/chip/divider/snackbar/appbar/bottom-nav đồng bộ với bảng màu
/// thương hiệu. Nhờ vậy phần lớn màn hình đẹp lên mà không phải sửa từng file.
class AppTheme {
  const AppTheme._();

  static const _radiusMd = AppColors.radiusMd;

  // ------------------------------------------------------------------
  // TYPOGRAPHY — thang chữ dùng chung
  // ------------------------------------------------------------------
  static TextTheme _textTheme(Color primary, Color secondary) {
    TextStyle t(double size, FontWeight weight,
            {double height = 1.35, double spacing = 0, Color? color}) =>
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: spacing,
          color: color ?? primary,
        );

    return TextTheme(
      // Tiêu đề lớn
      headlineMedium: t(24, FontWeight.w800, height: 1.2, spacing: -0.4),
      headlineSmall: t(20, FontWeight.w800, height: 1.2, spacing: -0.3),
      titleLarge: t(18, FontWeight.w700, height: 1.25, spacing: -0.2),
      titleMedium: t(16, FontWeight.w700, height: 1.3),
      titleSmall: t(14, FontWeight.w600, height: 1.3),
      // Nội dung
      bodyLarge: t(15, FontWeight.w500, height: 1.45),
      bodyMedium: t(14, FontWeight.w500, height: 1.45, color: primary),
      bodySmall: t(12.5, FontWeight.w500, height: 1.4, color: secondary),
      // Nhãn / caption
      labelLarge: t(14, FontWeight.w700, height: 1.2, spacing: 0.1),
      labelMedium: t(12, FontWeight.w600, height: 1.2, spacing: 0.2),
      labelSmall: t(11, FontWeight.w600, height: 1.2, spacing: 0.3, color: secondary),
    );
  }

  static InputDecorationTheme _inputTheme({
    required Color fill,
    required Color border,
  }) {
    OutlineInputBorder side(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMd),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w500,
      ),
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      border: side(border),
      enabledBorder: side(border),
      focusedBorder: side(AppColors.primary, 1.6),
      errorBorder: side(AppColors.danger),
      focusedErrorBorder: side(AppColors.danger, 1.6),
    );
  }

  static FilledButtonThemeData get _filledButton => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          minimumSize: const Size.fromHeight(50),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
          ),
        ),
      );

  static OutlinedButtonThemeData get _outlinedButton => OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          minimumSize: const Size.fromHeight(50),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
          ),
        ),
      );

  static TextButtonThemeData get _textButton => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      );

  // ------------------------------------------------------------------
  // LIGHT
  // ------------------------------------------------------------------
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme(AppColors.textPrimary, AppColors.textSecondary),
      inputDecorationTheme:
          _inputTheme(fill: AppColors.canvasAlt, border: AppColors.border),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: _filledButton,
      outlinedButtonTheme: _outlinedButton,
      textButtonTheme: _textButton,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSoft,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.brandTint,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // DARK
  // ------------------------------------------------------------------
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primarySoft,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.darkSurface,
      onSurface: const Color(0xFFE6EDF3),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkCanvas,
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme(
        const Color(0xFFE6EDF3),
        const Color(0xFF9BA7B4),
      ),
      inputDecorationTheme: _inputTheme(
        fill: AppColors.darkSurface,
        border: AppColors.darkBorder,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      filledButtonTheme: _filledButton,
      outlinedButtonTheme: _outlinedButton,
      textButtonTheme: _textButton,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: Color(0xFFE6EDF3),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFFE6EDF3),
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primarySoft,
        unselectedItemColor: Color(0xFF6B7684),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF14261B),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primarySoft,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkSurfaceAlt,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
      ),
    );
  }
}
