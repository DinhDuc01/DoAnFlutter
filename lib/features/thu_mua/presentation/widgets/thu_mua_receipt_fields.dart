import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/thu_mua_receipt.dart';

class ThuMuaReceiptFields extends StatelessWidget {
  const ThuMuaReceiptFields({
    required this.receipt,
    super.key,
  });

  final ThuMuaReceipt receipt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ReadonlyField(
            label: 'Mã phiếu nhập',
            value: receipt.receiptCode,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ReadonlyField(
            label: 'Khối lượng (kg)',
            value: receipt.weightKg.toStringAsFixed(2),
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
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderFor(context)),
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
              color: AppColors.textPrimaryFor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
