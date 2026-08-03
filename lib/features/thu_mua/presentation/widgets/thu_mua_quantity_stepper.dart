import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget Bộ tăng giảm số lượng nhập kho (Quantity Stepper).
/// Hỗ trợ hiển thị cảnh báo (Warning) hoặc lỗi (Error) thay đổi màu sắc khi các chỉ số IoT hoặc nghiệp vụ bị kích hoạt.
class ThuMuaQuantityStepper extends StatelessWidget {
  const ThuMuaQuantityStepper({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    this.hasWarning = false,
    this.hasError = false,
    super.key,
  });

  /// Số lượng hiện tại hiển thị ở giữa.
  final int quantity;

  /// Callback khi nhấn nút giảm (-).
  final VoidCallback onDecrease;

  /// Callback khi nhấn nút tăng (+).
  final VoidCallback onIncrease;

  /// Cờ hiển thị cảnh báo lệch cân IoT (Đổi viền sang màu cam).
  final bool hasWarning;

  /// Cờ hiển thị lỗi nghiệp vụ (Đổi màu số lượng sang màu đỏ).
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasWarning
              ? const Color(0xFFD97706) // Đường viền màu vàng cam khi lệch cân
              : AppColors.borderFor(context),
          width: hasWarning ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Số lượng nhập',
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Nút giảm số lượng
              _RoundQuantityButton(
                icon: Icons.remove,
                onPressed: onDecrease,
                isDisabled: quantity <= 0,
              ),
              Expanded(
                child: Column(
                  children: [
                    // Số lượng lớn ở chính giữa
                    Text(
                      '$quantity',
                      style: TextStyle(
                        color: hasError
                            ? const Color(0xFFEF4444) // Chữ đỏ nếu có lỗi
                            : AppColors.textPrimaryFor(context),
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'bao',
                      style: TextStyle(
                        color: AppColors.textSecondaryFor(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Nút tăng số lượng
              _RoundQuantityButton(
                icon: Icons.add,
                onPressed: onIncrease,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget nút tròn tăng/giảm số lượng.
class _RoundQuantityButton extends StatelessWidget {
  const _RoundQuantityButton({
    required this.icon,
    required this.onPressed,
    this.color,
    this.isDisabled = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDisabled
        ? AppColors.border
        : color ?? AppColors.border.withValues(alpha: 0.85);
    final foregroundColor =
        color == null ? AppColors.textSecondaryFor(context) : Colors.white;

    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton.filled(
        onPressed: isDisabled ? null : onPressed,
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}
