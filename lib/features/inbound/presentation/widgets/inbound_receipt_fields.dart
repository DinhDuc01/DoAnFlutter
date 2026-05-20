import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/inbound_receipt.dart';

class InboundReceiptFields extends StatelessWidget {
  const InboundReceiptFields({
    required this.receipt,
    super.key,
  });

  final InboundReceipt receipt;

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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
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
