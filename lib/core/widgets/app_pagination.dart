import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Thanh phân trang theo số trang (thay cho kiểu cuộn-tải-thêm vô hạn).
///
/// Hiển thị cửa sổ tối đa 5 số trang quanh trang hiện tại kèm nút lùi/tiến và
/// tổng số bản ghi. Widget thuần hiển thị — màn hình cha giữ [page] và gọi API
/// lại trong [onChanged].
class AppPagination extends StatelessWidget {
  const AppPagination({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  /// Trang hiện tại, bắt đầu từ 1.
  final int page;

  /// Tổng số trang (tối thiểu 1).
  final int totalPages;

  /// Tổng số bản ghi khớp bộ lọc — dùng cho dòng mô tả.
  final int total;

  final ValueChanged<int> onChanged;

  /// Khóa thao tác khi đang tải để tránh bấm chồng nhiều trang.
  final bool enabled;

  /// Cửa sổ số trang quanh trang hiện tại, luôn nằm trong [1, totalPages].
  List<int> get _window {
    final pages = <int>[];
    var start = page - 2;
    var end = page + 2;
    if (start < 1) {
      end += 1 - start;
      start = 1;
    }
    if (end > totalPages) {
      start -= end - totalPages;
      end = totalPages;
    }
    if (start < 1) start = 1;
    for (var i = start; i <= end; i++) {
      pages.add(i);
    }
    return pages;
  }

  void _go(int target) {
    if (!enabled) return;
    if (target < 1 || target > totalPages || target == page) return;
    onChanged(target);
  }

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();

    final secondary = AppColors.textSecondaryFor(context);
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Trang trước',
                onTap: enabled && page > 1 ? () => _go(page - 1) : null,
              ),
              const SizedBox(width: 6),
              for (final item in _window) ...[
                _PageButton(
                  value: item,
                  selected: item == page,
                  onTap: enabled ? () => _go(item) : null,
                ),
                const SizedBox(width: 6),
              ],
              _NavButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Trang sau',
                onTap: enabled && page < totalPages ? () => _go(page + 1) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Trang $page/$totalPages · $total bản ghi',
          style: TextStyle(fontSize: 12, color: secondary),
        ),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceFor(context),
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Container(
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderFor(context),
            ),
          ),
          child: Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: selected
                  ? Colors.white
                  : AppColors.textPrimaryFor(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          child: Container(
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              border: Border.all(color: AppColors.borderFor(context)),
            ),
            child: Icon(
              icon,
              size: 20,
              color: disabled
                  ? AppColors.textTertiary
                  : AppColors.textPrimaryFor(context),
            ),
          ),
        ),
      ),
    );
  }
}
