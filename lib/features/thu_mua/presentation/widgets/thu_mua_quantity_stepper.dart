import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Direct bag-count input. The plus/minus stepper is intentionally removed so
/// operators can enter the counted number of bags without repeated taps.
class ThuMuaQuantityStepper extends StatelessWidget {
  const ThuMuaQuantityStepper({
    required this.quantity,
    required this.onChanged,
    this.hasWarning = false,
    this.hasError = false,
    super.key,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final bool hasWarning;
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
              ? const Color(0xFFD97706)
              : AppColors.borderFor(context),
          width: hasWarning ? 1.5 : 1,
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
          TextFormField(
            key: const ValueKey('inbound_quantity_input'),
            initialValue: '$quantity',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: hasError
                  ? const Color(0xFFEF4444)
                  : AppColors.textPrimaryFor(context),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
            decoration: const InputDecoration(
              suffixText: ' bao',
              hintText: 'Nhập số bao',
            ),
            onChanged: (value) => onChanged(int.tryParse(value) ?? 0),
          ),
        ],
      ),
    );
  }
}
