import 'package:flutter/material.dart';

/// Bảng màu & design tokens của ứng dụng.
///
/// Palette được đồng bộ với bản web (DoAnFrontend) để mobile và web nhìn
/// "cùng một nhà": xanh lá thương hiệu #16a34a, xanh rừng đậm #166534,
/// nền xanh nhạt #f0fdf4 / #dcfce7.
///
/// Các thành viên cũ (primary, textSecondaryFor, surfaceFor...) được GIỮ
/// NGUYÊN tên & chữ ký để không phá vỡ ~50 màn đang import file này.
class AppColors {
  const AppColors._(); // Hạn chế khởi tạo

  // ------------------------------------------------------------------
  // BRAND — xanh lá (đồng bộ web)
  // ------------------------------------------------------------------
  static const primary = Color(0xFF16A34A); // green-600 (web primary)
  static const primaryDark = Color(0xFF15803D); // green-700
  static const forest = Color(0xFF166534); // green-800 (header đậm)
  static const forestDeep = Color(0xFF14532D); // green-900 (sidebar web)
  static const primarySoft = Color(0xFF22C55E); // green-500 (accent sáng)

  /// Tint nền nhạt của thương hiệu.
  static const brandTint = Color(0xFFF0FDF4); // green-50
  static const brandTintStrong = Color(0xFFDCFCE7); // green-100

  // Gradient nền (giữ tên cũ để tương thích)
  static const backgroundStart = Color(0xFFF0FDF4);
  static const backgroundEnd = Color(0xFFDCFCE7);

  // ------------------------------------------------------------------
  // NEUTRAL / SURFACE
  // ------------------------------------------------------------------
  static const surface = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF4FBF7); // nền chính sáng (xanh cực nhạt)
  static const canvasAlt = Color(0xFFF9FAFB); // nền phụ / field fill
  static const textPrimary = Color(0xFF0F172A); // slate-900
  static const textSecondary = Color(0xFF64748B); // slate-500
  static const textTertiary = Color(0xFF94A3B8); // slate-400
  static const border = Color(0xFFE5E7EB); // gray-200
  static const borderSoft = Color(0xFFF1F5F9); // slate-100 (divider mảnh)

  // Dark surfaces
  static const darkCanvas = Color(0xFF0D1117); // đồng bộ web dark body
  static const darkSurface = Color(0xFF161B22);
  static const darkSurfaceAlt = Color(0xFF1F2937);
  static const darkBorder = Color(0xFF30363D);

  // ------------------------------------------------------------------
  // SEMANTIC — trạng thái
  // ------------------------------------------------------------------
  static const success = Color(0xFF16A34A);
  static const successTint = Color(0xFFDCFCE7);
  static const warning = Color(0xFFD97706); // amber-600
  static const warningTint = Color(0xFFFEF3C7);
  static const danger = Color(0xFFDC2626); // red-600
  static const dangerTint = Color(0xFFFEE2E2);
  static const info = Color(0xFF2563EB); // blue-600
  static const infoTint = Color(0xFFDBEAFE);
  static const accentPink = Color(0xFFDB2777);
  static const accentPurple = Color(0xFF7C3AED);
  static const accentTeal = Color(0xFF0F766E);

  // ------------------------------------------------------------------
  // TOKENS — bo góc, khoảng cách, đổ bóng
  // ------------------------------------------------------------------
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusPill = 999;

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;

  /// Bóng mềm dùng cho card nổi trên nền.
  static List<BoxShadow> get softShadow => const [
        BoxShadow(
          color: Color(0x0F0F172A), // slate-900 @ ~6%
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ];

  /// Bóng rất nhẹ dùng cho ô lưới / phím tắt.
  static List<BoxShadow> get tinyShadow => const [
        BoxShadow(
          color: Color(0x080F172A),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ];

  // ------------------------------------------------------------------
  // HELPERS THEO CHẾ ĐỘ SÁNG/TỐI (giữ nguyên chữ ký cũ)
  // ------------------------------------------------------------------
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundFor(BuildContext context) =>
      isDark(context) ? darkCanvas : canvas;

  static Color surfaceFor(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color subtleSurfaceFor(BuildContext context) =>
      isDark(context) ? darkSurfaceAlt : canvasAlt;

  static Color textPrimaryFor(BuildContext context) =>
      isDark(context) ? const Color(0xFFE6EDF3) : textPrimary;

  static Color textSecondaryFor(BuildContext context) =>
      isDark(context) ? const Color(0xFF9BA7B4) : textSecondary;

  static Color borderFor(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  /// Tint thương hiệu theo chế độ (dùng cho vùng nhấn nhẹ).
  static Color brandTintFor(BuildContext context) =>
      isDark(context) ? const Color(0xFF14261B) : brandTint;
}
