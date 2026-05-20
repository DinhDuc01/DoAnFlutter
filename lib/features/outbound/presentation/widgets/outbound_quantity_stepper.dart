import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class OutboundQuantityStepper extends StatelessWidget {
  const OutboundQuantityStepper({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    super.key,
  });

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  static const _accent = Color(0xFF3478F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Số lượng xuất',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _RoundQuantityButton(
                icon: Icons.remove,
                onPressed: onDecrease,
                isDisabled: quantity <= 0,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$quantity',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'cái',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _RoundQuantityButton(
                icon: Icons.add,
                onPressed: onIncrease,
                color: _accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
    final foregroundColor = color == null ? AppColors.textSecondary : Colors.white;

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
