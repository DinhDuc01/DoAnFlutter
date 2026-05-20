import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/inventory_check.dart';

class InventorySummaryFields extends StatelessWidget {
  const InventorySummaryFields({
    required this.check,
    super.key,
  });

  final InventoryCheck check;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ReadonlyField(
            label: 'Mã phiếu kiểm',
            value: check.checkCode,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ReadonlyField(
            label: 'Kho',
            value: check.warehouseName,
          ),
        ),
      ],
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
