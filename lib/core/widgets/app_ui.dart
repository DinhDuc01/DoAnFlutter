import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bộ widget dùng chung ("UI kit") cho toàn app — giúp mọi màn hình có cùng
/// ngôn ngữ thị giác với web: card bo góc + bóng mềm, header xanh gradient,
/// chip trạng thái, ô thống kê, tiêu đề mục.
///
/// Import: `import '../../../../core/widgets/app_ui.dart';`

/// Sắc thái ngữ nghĩa dùng cho chip / banner.
enum AppTone { neutral, brand, success, warning, danger, info }

extension AppToneColors on AppTone {
  Color get fg {
    switch (this) {
      case AppTone.brand:
      case AppTone.success:
        return AppColors.primaryDark;
      case AppTone.warning:
        return AppColors.warning;
      case AppTone.danger:
        return AppColors.danger;
      case AppTone.info:
        return AppColors.info;
      case AppTone.neutral:
        return AppColors.textSecondary;
    }
  }

  Color get bg {
    switch (this) {
      case AppTone.brand:
      case AppTone.success:
        return AppColors.successTint;
      case AppTone.warning:
        return AppColors.warningTint;
      case AppTone.danger:
        return AppColors.dangerTint;
      case AppTone.info:
        return AppColors.infoTint;
      case AppTone.neutral:
        return AppColors.canvasAlt;
    }
  }
}

/// Card chuẩn: nền surface, bo góc, viền mảnh + bóng mềm; tự đổi theo dark mode.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.margin,
    this.radius = AppColors.radiusLg,
    this.color,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: dark ? null : AppColors.softShadow,
      ),
      child: child,
    );

    if (onTap == null) return Container(margin: margin, child: content);

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      ),
    );
  }
}

/// Header xanh gradient bo góc dưới — thay cho các Container header hard-code.
class AppGradientHeader extends StatelessWidget {
  const AppGradientHeader({
    required this.title,
    this.subtitle,
    this.overline,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 22),
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? overline;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (overline != null)
                  Text(
                    overline!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (overline != null) const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Tiêu đề của một mục (section) trong màn hình.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.icon,
    this.action,
    this.padding = const EdgeInsets.only(bottom: 10, top: 4),
    super.key,
  });

  final String title;
  final IconData? icon;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppColors.textPrimaryFor(context),
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Chip trạng thái nhỏ, màu theo [AppTone].
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    required this.label,
    this.tone = AppTone.neutral,
    this.icon,
    this.dense = false,
    super.key,
  });

  final String label;
  final AppTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: tone.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: tone.fg,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô thống kê nhỏ (label trên, giá trị to dưới) — hàng KPI đầu danh sách.
class AppStatTile extends StatelessWidget {
  const AppStatTile({
    required this.label,
    required this.value,
    this.icon,
    this.tone = AppTone.brand,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: tone.fg),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryFor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.textPrimaryFor(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner thông tin/cảnh báo (thay cho các alert box hard-code).
class AppInfoBanner extends StatelessWidget {
  const AppInfoBanner({
    required this.message,
    this.tone = AppTone.warning,
    this.icon = Icons.info_outline_rounded,
    this.onTap,
    super.key,
  });

  final String message;
  final AppTone tone;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: tone.bg,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          child: Row(
            children: [
              Icon(icon, color: tone.fg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: tone.fg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: tone.fg, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
