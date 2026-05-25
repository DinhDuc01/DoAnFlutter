import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class AccountMenuSection extends StatelessWidget {
  const AccountMenuSection({
    required this.items,
    this.title,
    super.key,
  });

  final String? title;
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
          for (var index = 0; index < items.length; index++) ...[
            items[index],
            if (index < items.length - 1)
              Divider(
                height: 1,
                indent: 58,
                color: colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

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
    final isToggle = value != null;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: isToggle ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
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
