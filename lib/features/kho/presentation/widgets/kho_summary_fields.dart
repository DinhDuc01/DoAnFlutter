import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/kho_check.dart';

class KhoSummaryFields extends StatelessWidget {
  const KhoSummaryFields({
    required this.check,
    super.key,
  });

  final KhoCheck check;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ReadonlyField(
                label: 'Mã phiếu kiểm kê',
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
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ReadonlyField(
                label: 'Sản phẩm',
                value: '${check.totalProducts}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReadonlyField(
                label: 'Tổng tồn hệ thống',
                value: '${check.totalSystemQuantity}',
                valueColor: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderFor(context)),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondaryFor(context),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimaryFor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
