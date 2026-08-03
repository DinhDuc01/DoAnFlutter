import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/giao_hang_receipt.dart';

class GiaoHangReceiptFields extends StatelessWidget {
  const GiaoHangReceiptFields({required this.receipt, super.key});
  final GiaoHangReceipt receipt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        children: [
          _row('Mã đơn tạm', receipt.receiptCode),
          _row('Kho xuất', receipt.warehouseName),
          _row('Vị trí', receipt.locationCode ?? 'Không phân vị trí'),
          _row('Tồn khả dụng', '${receipt.currentStock} bao'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
