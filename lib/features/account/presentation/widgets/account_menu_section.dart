import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Nhóm các mục menu tài khoản (Account Menu Section).
/// Vẽ các danh sách lựa chọn có tiêu đề nhóm và đường gạch nối (Divider) lõm vào 58px.
class AccountMenuSection extends StatelessWidget {
  const AccountMenuSection({
    required this.items,
    this.title,
    super.key,
  });

  /// Tiêu đề nhóm menu (ví dụ: "CÀI ĐẶT", "TÀI KHOẢN") - có thể bằng null.
  final String? title;

  /// Danh sách các mục con hiển thị trong nhóm.
  final List<AccountMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hiển thị tiêu đề nhóm nếu được truyền vào
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
              child: Text(
                title!,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          // Tạo vòng lặp vẽ các dòng con kèm đường gạch ngang ở giữa các dòng
          for (var index = 0; index < items.length; index++) ...[
            items[index],
            if (index < items.length - 1)
              Divider(
                height: 1,
                indent:
                    58, // Lùi lề đường kẻ để không chạm viền trái (tránh che icon)
                color: colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

/// Widget dòng menu tài khoản đơn lẻ.
/// Hỗ trợ 2 kiểu giao diện chính:
/// 1. Dạng Switch bật/tắt (AccountMenuItem.toggle)
/// 2. Dạng Nút điều hướng Click sang màn hình khác (AccountMenuItem.navigation)
class AccountMenuItem extends StatelessWidget {
  const AccountMenuItem._({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.value,
    this.onChanged,
    this.onTap,
  });

  /// Constructor Factory khởi tạo một mục Toggle dạng Switch.
  factory AccountMenuItem.toggle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
  }) {
    return AccountMenuItem._(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
    );
  }

  /// Constructor Factory khởi tạo một mục điều hướng nhấn để xử lý hoặc chuyển trang.
  factory AccountMenuItem.navigation({
    required IconData icon,
    required Color iconColor,
    required String title,
    VoidCallback? onTap,
    String? subtitle,
  }) {
    return AccountMenuItem._(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Nếu biến value khác null tức là giao diện Switch Toggle
    final isToggle = value != null;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: isToggle
          ? null
          : onTap, // Bật tắt Switch thì bấm thẳng Switch, click thường thì chỉ chạy onTap
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Ô tròn chứa Icon đại diện cho mục menu
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 12),
            // Phần nhãn văn bản: Tiêu đề & Phụ đề
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Phân biệt hiển thị đuôi dòng: Switch hoặc Icon mũi tên >
            if (isToggle)
              Switch(
                value: value!,
                activeThumbColor: AppColors.primary,
                onChanged: onChanged,
              )
            else
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
