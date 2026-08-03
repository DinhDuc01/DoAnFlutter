import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Thanh phân trang cho danh sách thông báo (Trước / Trang x/y / Sau).
class NotificationsPager extends StatelessWidget {
  const NotificationsPager({
    required this.page,
    required this.totalPages,
    required this.onChanged,
    super.key,
  });

  /// Trang hiện tại (bắt đầu từ 1).
  final int page;

  /// Tổng số trang.
  final int totalPages;

  /// Callback khi chọn trang mới.
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canPrev = page > 1;
    final canNext = page < totalPages;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: canPrev ? () => onChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Trang trước',
            color: AppColors.primary,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Trang $page/$totalPages',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: canNext ? () => onChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Trang sau',
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
